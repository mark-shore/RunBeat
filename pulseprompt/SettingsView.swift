import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var heartRateViewModel: HeartRateViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingRestingHRPicker = false
    @State private var showingMaxHRPicker = false
    @State private var showingZone1LowerPicker = false
    @State private var showingZone1Picker = false
    @State private var showingZone2Picker = false
    @State private var showingZone3Picker = false
    @State private var showingZone4Picker = false
    @State private var showingZone5Picker = false
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text("HEART RATE SETTINGS")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(2)
                    }
                    .padding(.top, 20)
                    
                    // Heart Rate Zones Description
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Heart Rate Zones")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Calculated using the scientifically validated heart rate reserve formula, your heart rate (HR) zones are personalized using your baseline resting HR and maximum HR.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    
                    // Resting and Max HR Inputs
                    VStack(spacing: 16) {
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("RESTING HR")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    Button(action: {}) {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                HStack {
                                    Button(action: {
                                        showingRestingHRPicker = true
                                    }) {
                                        Text("\(heartRateViewModel.restingHR)")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 80, height: 40)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.gray.opacity(0.1))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                    
                                    Text("bpm")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("MAX HR")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    Button(action: {}) {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                HStack {
                                    Button(action: {
                                        showingMaxHRPicker = true
                                    }) {
                                        Text("\(heartRateViewModel.maxHR)")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 80, height: 40)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.gray.opacity(0.1))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                    
                                    Text("bpm")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Manual Heart Rate Zones Toggle
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Manual Heart Rate Zones")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("As your fitness and RHR change, your HR zone ranges are adjusted automatically. You can manually update them if they don't feel normal to you.")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { !heartRateViewModel.useAutoZones },
                                set: { heartRateViewModel.useAutoZones = !$0 }
                            ))
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: .gray))
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Zone Display/Settings
                    if heartRateViewModel.useAutoZones {
                        AutoZonesDisplay(heartRateViewModel: heartRateViewModel)
                            .padding(.horizontal, 20)
                    } else {
                        ManualZonesSettings(
                            heartRateViewModel: heartRateViewModel,
                            showingZone1LowerPicker: $showingZone1LowerPicker,
                            showingZone1Picker: $showingZone1Picker,
                            showingZone2Picker: $showingZone2Picker,
                            showingZone3Picker: $showingZone3Picker,
                            showingZone4Picker: $showingZone4Picker,
                            showingZone5Picker: $showingZone5Picker
                        )
                            .padding(.horizontal, 20)
                    }
                    
                    // Save Button
                    Button(action: {
                        // Settings are automatically saved via ViewModel
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                            
                            Text("Save Settings")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    // Settings are automatically saved via ViewModel
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showingRestingHRPicker) {
            RestingHRPickerView(restingHR: $heartRateViewModel.restingHR)
        }
        .sheet(isPresented: $showingMaxHRPicker) {
            MaxHRPickerView(maxHR: $heartRateViewModel.maxHR)
        }
        .sheet(isPresented: $showingZone1LowerPicker) {
            Zone1LowerPickerView(zone1Lower: $heartRateViewModel.zone1Lower)
        }
        .sheet(isPresented: $showingZone1Picker) {
            ZonePickerView(zoneNumber: 1, zoneUpper: $heartRateViewModel.zone1Upper)
        }
        .sheet(isPresented: $showingZone2Picker) {
            ZonePickerView(zoneNumber: 2, zoneUpper: $heartRateViewModel.zone2Upper)
        }
        .sheet(isPresented: $showingZone3Picker) {
            ZonePickerView(zoneNumber: 3, zoneUpper: $heartRateViewModel.zone3Upper)
        }
        .sheet(isPresented: $showingZone4Picker) {
            ZonePickerView(zoneNumber: 4, zoneUpper: $heartRateViewModel.zone4Upper)
        }
        .sheet(isPresented: $showingZone5Picker) {
            ZonePickerView(zoneNumber: 5, zoneUpper: $heartRateViewModel.zone5Upper)
        }
    }
}

struct AutoZonesDisplay: View {
    @ObservedObject var heartRateViewModel: HeartRateViewModel
    
    private var autoZones: (Int, Int, Int, Int, Int, Int) {
        return heartRateViewModel.currentZoneLimits
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("ZONE")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("ZONE MIN")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("ZONE MAX")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            let zones = autoZones
            let zoneColors: [Color] = [.red, .orange, .yellow, .green, .blue]
            let zoneRanges = [
                (zones.0, zones.1), // Zone 1: zone1Lower to zone1Upper
                (zones.1 + 1, zones.2), // Zone 2: zone1Upper+1 to zone2Upper
                (zones.2 + 1, zones.3), // Zone 3: zone2Upper+1 to zone3Upper
                (zones.3 + 1, zones.4), // Zone 4: zone3Upper+1 to zone4Upper
                (zones.4 + 1, zones.5)  // Zone 5: zone4Upper+1 to zone5Upper
            ]
            
            ForEach(0..<5, id: \.self) { index in
                HStack {
                    HStack {
                        Rectangle()
                            .fill(zoneColors[4-index])
                            .frame(width: 4, height: 40)
                        
                        Text("Zone \(5-index)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Text("\(zoneRanges[4-index].0)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("bpm")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(zoneRanges[4-index].1)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("bpm")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            }
        }
    }
}

struct ManualZonesSettings: View {
    @ObservedObject var heartRateViewModel: HeartRateViewModel
    @Binding var showingZone1LowerPicker: Bool
    @Binding var showingZone1Picker: Bool
    @Binding var showingZone2Picker: Bool
    @Binding var showingZone3Picker: Bool
    @Binding var showingZone4Picker: Bool
    @Binding var showingZone5Picker: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Zone1SettingRow(
                heartRateViewModel: heartRateViewModel,
                onLowerTap: { showingZone1LowerPicker = true },
                onUpperTap: { showingZone1Picker = true }
            )
            
            ZoneSettingRow(
                zone: 2,
                title: "Zone 2 - Aerobic Base",
                subtitle: "Base training, fat burning",
                color: .green,
                upperLimit: heartRateViewModel.zone2Upper,
                onTap: { showingZone2Picker = true }
            )
            
            ZoneSettingRow(
                zone: 3,
                title: "Zone 3 - Aerobic Threshold",
                subtitle: "Moderate intensity",
                color: .yellow,
                upperLimit: heartRateViewModel.zone3Upper,
                onTap: { showingZone3Picker = true }
            )
            
            ZoneSettingRow(
                zone: 4,
                title: "Zone 4 - Lactate Threshold",
                subtitle: "Hard intensity",
                color: .orange,
                upperLimit: heartRateViewModel.zone4Upper,
                onTap: { showingZone4Picker = true }
            )
            
            ZoneSettingRow(
                zone: 5,
                title: "Zone 5 - VO2 Max",
                subtitle: "Very hard, neuromuscular",
                color: .red,
                upperLimit: heartRateViewModel.zone5Upper,
                onTap: { showingZone5Picker = true }
            )
        }
    }
}

struct Zone1SettingRow: View {
    @ObservedObject var heartRateViewModel: HeartRateViewModel
    let onLowerTap: () -> Void
    let onUpperTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Zone header
            HStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("1")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zone 1 - Active Recovery")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Easy pace, recovery")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Heart rate inputs
            HStack {
                Text("Lower limit:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Button(action: onLowerTap) {
                        Text("\(heartRateViewModel.zone1Lower)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Text("BPM")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            HStack {
                Text("Upper limit:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Button(action: onUpperTap) {
                        Text("\(heartRateViewModel.zone1Upper)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Text("BPM")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ZoneSettingRow: View {
    let zone: Int
    let title: String
    let subtitle: String
    let color: Color
    let upperLimit: Int
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Zone header
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("\(zone)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Heart rate input
            HStack {
                Text("Upper limit:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Button(action: onTap) {
                        Text("\(upperLimit)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    Text("BPM")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct RestingHRPickerView: View {
    @Binding var restingHR: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("RESTING HR")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(1)
                    
                    Picker("Resting HR", selection: $restingHR) {
                        ForEach(30...100, id: \.self) { hr in
                            Text("\(hr)")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .tag(hr)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 200)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            
                            Text("WHOOP determines your default resting HR based on recent data. Change it if you know it to be a different value.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    Button("SAVE") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
    }
}

struct MaxHRPickerView: View {
    @Binding var maxHR: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("MAX HR")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(1)
                    
                    Picker("Max HR", selection: $maxHR) {
                        ForEach(120...220, id: \.self) { hr in
                            Text("\(hr)")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .tag(hr)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 200)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            
                            Text("WHOOP determines your default max HR based on your age. Change it if you know it to be a different value.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    Button("SAVE") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
    }
}

struct ZonePickerView: View {
    let zoneNumber: Int
    @Binding var zoneUpper: Int
    @Environment(\.dismiss) private var dismiss
    
    private var zoneTitle: String {
        switch zoneNumber {
        case 1: return "Zone 1 - Active Recovery"
        case 2: return "Zone 2 - Aerobic Base"
        case 3: return "Zone 3 - Aerobic Threshold"
        case 4: return "Zone 4 - Lactate Threshold"
        case 5: return "Zone 5 - VO2 Max"
        default: return "Zone \(zoneNumber)"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("ZONE \(zoneNumber) UPPER LIMIT")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(1)
                    
                    Text(zoneTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Picker("Zone \(zoneNumber) Upper", selection: $zoneUpper) {
                        ForEach(60...220, id: \.self) { hr in
                            Text("\(hr)")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .tag(hr)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 200)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            
                            Text("Set the upper limit for \(zoneTitle.lowercased()). This will be the maximum heart rate for this zone.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    Button("SAVE") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
    }
}

struct Zone1LowerPickerView: View {
    @Binding var zone1Lower: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("ZONE 1 LOWER LIMIT")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .tracking(1)
                    
                    Text("Zone 1 - Active Recovery")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Picker("Zone 1 Lower", selection: $zone1Lower) {
                        ForEach(30...150, id: \.self) { hr in
                            Text("\(hr)")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .tag(hr)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 200)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            
                            Text("Set the lower limit for Zone 1 - Active Recovery. This will be the minimum heart rate for this zone.")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    Button("SAVE") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
    }
}