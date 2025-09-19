import CoreBluetooth
import Foundation
import Combine

class HeartRateManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var centralManager: CBCentralManager!
    private var heartRatePeripheral: CBPeripheral?
    private var isMonitoring = false

    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementCharacteristicUUID = CBUUID(string: "2A37")

    var onNewHeartRate: ((Int) -> Void)?

    // Intent observation (keeping existing behavior unchanged for now)
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        // Enable background operation with restoration identifier
        let options: [String: Any] = [
            CBCentralManagerOptionRestoreIdentifierKey: "RunBeatCentralManager",
            CBCentralManagerOptionShowPowerAlertKey: true
        ]
        let bleQueue = DispatchQueue(label: "com.runbeat.ble", qos: .userInitiated)
        centralManager = CBCentralManager(delegate: self, queue: bleQueue, options: options)

        setupIntentObservation()
    }
    
    func startMonitoring() {
        isMonitoring = true
        if centralManager.state == .poweredOn {
            startScanning()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        centralManager.stopScan()
        
        if let peripheral = heartRatePeripheral, peripheral.state == .connected || peripheral.state == .connecting {
            centralManager.cancelPeripheralConnection(peripheral)
            print("🔌 Disconnecting from: \(peripheral.name ?? "Unknown device")")
        }
        
        heartRatePeripheral = nil
        print("🔋 Heart rate monitoring stopped")
    }
    
    private func startScanning() {
        guard isMonitoring else { return }
        
        let scanOptions: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ]
        centralManager.scanForPeripherals(withServices: [heartRateServiceUUID], options: scanOptions)
        print("🔍 Scanning for heart rate devices...")
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && isMonitoring {
            startScanning()
        }
    }
    
    // This method is called when the app is restored from background
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        print("🔄 Restoring Bluetooth state in background")
        
        // Only restore if we're currently monitoring
        if isMonitoring {
            // Restore connected peripherals
            if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
                for peripheral in peripherals {
                    heartRatePeripheral = peripheral
                    heartRatePeripheral?.delegate = self
                    print("📱 Restored connection to: \(peripheral.name ?? "Unknown device")")
                }
            }
        } else {
            // If we're not monitoring, disconnect any restored peripherals
            if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
                for peripheral in peripherals {
                    centralManager.cancelPeripheralConnection(peripheral)
                    print("🔋 Disconnected restored peripheral: \(peripheral.name ?? "Unknown device") (monitoring is off)")
                }
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any], rssi RSSI: NSNumber) {
        heartRatePeripheral = peripheral
        heartRatePeripheral?.delegate = self
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("🔗 Connected to heart rate device: \(peripheral.name ?? "Unknown")")
        peripheral.discoverServices([heartRateServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("📱 Disconnected from heart rate device: \(peripheral.name ?? "Unknown")")
        if let error = error {
            print("❌ Disconnection error: \(error.localizedDescription)")
        }
        
        // Only attempt to reconnect if we're still monitoring
        if central.state == .poweredOn && isMonitoring {
            print("🔄 Attempting to reconnect...")
            centralManager.connect(peripheral, options: nil)
        } else if !isMonitoring {
            print("🔋 Not reconnecting - monitoring is disabled")
            heartRatePeripheral = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let service = peripheral.services?.first(where: { $0.uuid == heartRateServiceUUID }) {
            peripheral.discoverCharacteristics([heartRateMeasurementCharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristic = service.characteristics?.first(where: { $0.uuid == heartRateMeasurementCharacteristicUUID }) {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        let bpm = decodeHeartRate(from: data)
        onNewHeartRate?(bpm)
        print("💓 Heart Rate Updated: \(bpm) BPM")
    }

    private func decodeHeartRate(from data: Data) -> Int {
        let byteArray = [UInt8](data)
        return byteArray[0] & 0x01 == 0 ? Int(byteArray[1]) :
            Int(UInt16(byteArray[1]) | UInt16(byteArray[2]) << 8)
    }

    // MARK: - Intent Observation

    private func setupIntentObservation() {
        IntentCoordinator.shared.$currentIntent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] intent in
                self?.handleIntentChange(intent)
            }
            .store(in: &cancellables)

        AppLogger.debug("HeartRateManager intent observation setup complete", component: "HeartRate")
    }

    private func handleIntentChange(_ intent: AppIntent) {
        AppLogger.debug("HeartRateManager received intent change: \(intent.description)", component: "HeartRate")

        // TODO: In Phase 2, this will replace the existing isMonitoring logic
        // For now, just logging to verify observation works
        //
        // Future logic will be:
        // - Start monitoring when intent.isTrainingSession becomes true
        // - Stop monitoring when intent becomes .idle
        // - No manual startMonitoring/stopMonitoring calls needed
    }
}
