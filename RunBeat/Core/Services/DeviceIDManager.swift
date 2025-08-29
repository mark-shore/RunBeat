import Foundation
import UIKit

/**
 * DeviceIDManager
 *
 * Manages device identification for backend communication.
 * Uses UIDevice.current.identifierForVendor with UserDefaults backup
 * to ensure consistent device ID across app launches.
 */
class DeviceIDManager {
    
    static let shared = DeviceIDManager()
    
    private let userDefaults = UserDefaults.standard
    private let deviceIDKey = "RunBeat_Device_ID"
    
    private init() {}
    
    /**
     * Get the unique device identifier for backend communication
     *
     * Uses the following priority:
     * 1. Cached value from UserDefaults (for consistency)
     * 2. UIDevice.current.identifierForVendor (hardware-based)
     * 3. Generated UUID (fallback for simulator/edge cases)
     *
     * The device ID is persisted to UserDefaults to ensure consistency
     * across app launches, even if identifierForVendor changes.
     */
    var deviceID: String {
        // Check if we have a cached device ID
        if let cachedID = userDefaults.string(forKey: deviceIDKey), !cachedID.isEmpty {
            return cachedID
        }
        
        // Try to get the vendor identifier
        let newDeviceID: String
        if let vendorID = UIDevice.current.identifierForVendor?.uuidString {
            newDeviceID = vendorID
        } else {
            // Fallback to generated UUID (simulator or unusual cases)
            newDeviceID = UUID().uuidString
        }
        
        // Cache the device ID for future use
        userDefaults.set(newDeviceID, forKey: deviceIDKey)
        userDefaults.synchronize()
        
        return newDeviceID
    }
    
    /**
     * Reset the device ID (for testing or account linking changes)
     *
     * This will force generation of a new device ID on the next access.
     * Use with caution as this may affect backend token association.
     */
    func resetDeviceID() {
        userDefaults.removeObject(forKey: deviceIDKey)
        userDefaults.synchronize()
    }
    
    /**
     * Get device information for debugging and logging
     */
    var deviceInfo: [String: String] {
        return [
            "device_id": deviceID,
            "device_model": UIDevice.current.model,
            "device_name": UIDevice.current.name,
            "system_version": UIDevice.current.systemVersion,
            "vendor_id": UIDevice.current.identifierForVendor?.uuidString ?? "unavailable"
        ]
    }
    
    /**
     * Check if the current device ID is from vendor identifier or generated
     */
    var isVendorBased: Bool {
        guard let cachedID = userDefaults.string(forKey: deviceIDKey),
              let vendorID = UIDevice.current.identifierForVendor?.uuidString else {
            return false
        }
        return cachedID == vendorID
    }
}