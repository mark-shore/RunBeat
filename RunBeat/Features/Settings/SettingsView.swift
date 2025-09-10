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
            AppColors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Header
                    VStack(spacing: AppSpacing.sm) {
                        Text("HEART RATE SETTINGS")
                            .font(AppTypography.title1)
                            .foregroundColor(AppColors.onBackground)
                            .tracking(2)
                    }
                    .padding(.top, AppSpacing.lg)
                    
                    // Heart Rate Zones Description
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Heart Rate Zones")
                                .font(AppTypography.title2)
                                .foregroundColor(AppColors.onBackground)
                            
                            Text("Calculated using the scientifically validated heart rate reserve formula, your heart rate (HR) zones are personalized using your baseline resting HR and maximum HR.")
                                .font(AppTypography.callout)
                                .foregroundColor(AppColors.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    
                    // Resting and Max HR Inputs
                    AppCard {
                        VStack(spacing: AppSpacing.md) {
                            HStack(spacing: AppSpacing.lg) {
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    HStack {
                                        Text("RESTING HR")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.secondary)
                                        
                                        Button(action: {}) {
                                            Image(systemName: "info.circle")
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.secondary)
                                        }
                                    }
                                    
                                    HStack {
                                        Button(action: {
                                            showingRestingHRPicker = true
                                        }) {
                                            Text("\(heartRateViewModel.restingHR)")
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(AppColors.onBackground)
                                                .frame(width: 80, height: AppSpacing.minTouchTarget)
                                                .background(
                                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                                        .fill(AppColors.surface)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                                        .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                                                )
                                        }
                                        
                                        Text("bpm")
                                            .font(AppTypography.callout)
                                            .foregroundColor(AppColors.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    HStack {
                                        Text("MAX HR")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.secondary)
                                        
                                        Button(action: {}) {
                                            Image(systemName: "info.circle")
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.secondary)
                                        }
                                    }
                                    
                                    HStack {
                                        Button(action: {
                                            showingMaxHRPicker = true
                                        }) {
                                            Text("\(heartRateViewModel.maxHR)")
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(AppColors.onBackground)
                                                .frame(width: 80, height: AppSpacing.minTouchTarget)
                                                .background(
                                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                                        .fill(AppColors.surface)
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                                        .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                                                )
                                        }
                                        
                                        Text("bpm")
                                            .font(AppTypography.callout)
                                            .foregroundColor(AppColors.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    
                    // Manual Heart Rate Zones Toggle
                    AppCard {
                        HStack {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Text("Manual Heart Rate Zones")
                                    .font(AppTypography.headline)
                                    .foregroundColor(AppColors.onBackground)
                                
                                Text("You can manually update your HR zone ranges if they don't feel normal to you.")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { !heartRateViewModel.useAutoZones },
                                set: { heartRateViewModel.useAutoZones = !$0 }
                            ))
                                .labelsHidden()
                                .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    
                    // Zone Display/Settings
                    if heartRateViewModel.useAutoZones {
                        AutoZonesDisplay(heartRateViewModel: heartRateViewModel)
                            .padding(.horizontal, AppSpacing.screenMargin)
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
                            .padding(.horizontal, AppSpacing.screenMargin)
                    }
                    
                    // Save Button
                    AppButton("Save Settings", style: .primary) {
                        // Settings are automatically saved via ViewModel
                        dismiss()
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    .padding(.top, AppSpacing.lg)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                AppBackButton {
                    dismiss()
                }
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
        AppCard {
            VStack(spacing: AppSpacing.md) {
                HStack {
                    Text("ZONE")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)
                    
                    Spacer()
                    
                    Text("ZONE MIN")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)
                    
                    Spacer()
                    
                    Text("ZONE MAX")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)
                }
                
                let zones = autoZones
                let zoneColors: [Color] = [AppColors.zone1, AppColors.zone2, AppColors.zone3, AppColors.zone4, AppColors.zone5]
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
                            Circle()
                                .fill(zoneColors[4-index])
                                .frame(width: 12, height: 12)
                            
                            Text("Zone \(5-index)")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.onBackground)
                        }
                        
                        Spacer()
                        
                        Text("\(zoneRanges[4-index].0)")
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.secondary)
                        
                        Text("bpm")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary)
                        
                        Spacer()
                        
                        Text("\(zoneRanges[4-index].1)")
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.secondary)
                        
                        Text("bpm")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    .padding(.vertical, AppSpacing.sm)
                }
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
        VStack(spacing: AppSpacing.lg) {
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
        AppCard(style: .highlighted) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Zone header
                HStack {
                    Circle()
                        .fill(AppColors.zone1)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("1")
                                .font(AppTypography.caption.weight(.bold))
                                .foregroundColor(AppColors.onBackground)
                        )
                    
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Zone 1 - Active Recovery")
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.onBackground)
                        
                        Text("Easy pace, recovery")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    
                    Spacer()
                }
                
                // Heart rate inputs
                HStack {
                    Text("Lower limit:")
                        .font(AppTypography.callout)
                        .foregroundColor(AppColors.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: AppSpacing.xs) {
                        Button(action: onLowerTap) {
                            Text("\(heartRateViewModel.zone1Lower)")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.onBackground)
                                .frame(width: 80, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                        .fill(AppColors.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                        .stroke(AppColors.zone1.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        Text("BPM")
                            .font(AppTypography.callout)
                            .foregroundColor(AppColors.secondary)
                    }
                }
                
                HStack {
                    Text("Upper limit:")
                        .font(AppTypography.callout)
                        .foregroundColor(AppColors.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: AppSpacing.xs) {
                        Button(action: onUpperTap) {
                            Text("\(heartRateViewModel.zone1Upper)")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.onBackground)
                                .frame(width: 80, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                        .fill(AppColors.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                        .stroke(AppColors.zone1.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        Text("BPM")
                            .font(AppTypography.callout)
                            .foregroundColor(AppColors.secondary)
                    }
                }
            }
        }
    }
}

struct ZoneSettingRow: View {
    let zone: Int
    let title: String
    let subtitle: String
    let color: Color
    let upperLimit: Int
    let onTap: () -> Void
    
    private var zoneColor: Color {
        switch zone {
        case 0: return AppColors.zone0
        case 1: return AppColors.zone1
        case 2: return AppColors.zone2
        case 3: return AppColors.zone3
        case 4: return AppColors.zone4
        case 5: return AppColors.zone5
        default: return color
        }
    }
    
    var body: some View {
        AppCard(style: .highlighted) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Zone header
                HStack {
                    Circle()
                        .fill(zoneColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(zone)")
                                .font(AppTypography.caption.weight(.bold))
                                .foregroundColor(AppColors.onBackground)
                        )
                    
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(title)
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.onBackground)
                        
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    
                    Spacer()
                }
                
                // Heart rate input
                HStack {
                    Text("Upper limit:")
                        .font(AppTypography.callout)
                        .foregroundColor(AppColors.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: AppSpacing.xs) {
                        Button(action: onTap) {
                            Text("\(upperLimit)")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.onBackground)
                                .frame(width: 80, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                        .fill(AppColors.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                        .stroke(zoneColor.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        Text("BPM")
                            .font(AppTypography.callout)
                            .foregroundColor(AppColors.secondary)
                    }
                }
            }
        }
    }
}

struct RestingHRPickerView: View {
    @Binding var restingHR: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: AppSpacing.lg) {
                    Text("RESTING HR")
                        .font(AppTypography.title2)
                        .foregroundColor(AppColors.onBackground)
                        .tracking(1)
                    
                    Picker("Resting HR", selection: $restingHR) {
                        ForEach(30...100, id: \.self) { hr in
                            Text("\(hr)")
                                .font(AppTypography.timerDisplay)
                                .foregroundColor(AppColors.onBackground)
                                .tag(hr)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 200)
                    
                    AppCard(style: .highlighted) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppColors.primary)
                            
                            Text("Update your resting HR if you know it to be a different value.")
                                .font(AppTypography.callout)
                                .foregroundColor(AppColors.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    
                    Spacer()
                    
                    AppButton("SAVE", style: .primary) {
                        dismiss()
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.onBackground)
                            .font(AppTypography.headline)
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
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: AppSpacing.lg) {
                    Text("MAX HR")
                        .font(AppTypography.title2)
                        .foregroundColor(AppColors.onBackground)
                        .tracking(1)
                    
                    Picker("Max HR", selection: $maxHR) {
                        ForEach(120...220, id: \.self) { hr in
                            Text("\(hr)")
                                .font(AppTypography.timerDisplay)
                                .foregroundColor(AppColors.onBackground)
                                .tag(hr)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 200)
                    
                    AppCard(style: .highlighted) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppColors.primary)
                            
                            Text("Update your max HR if you know it to be a different value.")
                                .font(AppTypography.callout)
                                .foregroundColor(AppColors.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    
                    Spacer()
                    
                    AppButton("SAVE", style: .primary) {
                        dismiss()
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.onBackground)
                            .font(AppTypography.headline)
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
        case 0: return "Zone 0 - Rest/Recovery"
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
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: AppSpacing.lg) {
                    Text("ZONE \(zoneNumber) UPPER LIMIT")
                        .font(AppTypography.title2)
                        .foregroundColor(AppColors.onBackground)
                        .tracking(1)
                    
                    Text(zoneTitle)
                        .font(AppTypography.callout)
                        .foregroundColor(AppColors.secondary)
                    
                    Picker("Zone \(zoneNumber) Upper", selection: $zoneUpper) {
                        ForEach(60...220, id: \.self) { hr in
                            Text("\(hr)")
                                .font(AppTypography.timerDisplay)
                                .foregroundColor(AppColors.onBackground)
                                .tag(hr)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 200)
                    
                    AppCard(style: .highlighted) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppColors.primary)
                            
                            Text("Set the upper limit for \(zoneTitle.lowercased()). This will be the maximum heart rate for this zone.")
                                .font(AppTypography.callout)
                                .foregroundColor(AppColors.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    
                    Spacer()
                    
                    AppButton("SAVE", style: .primary) {
                        dismiss()
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.onBackground)
                            .font(AppTypography.headline)
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
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: AppSpacing.lg) {
                    Text("ZONE 1 LOWER LIMIT")
                        .font(AppTypography.title2)
                        .foregroundColor(AppColors.onBackground)
                        .tracking(1)
                    
                    Text("Zone 1 - Active Recovery")
                        .font(AppTypography.callout)
                        .foregroundColor(AppColors.secondary)
                    
                    Picker("Zone 1 Lower", selection: $zone1Lower) {
                        ForEach(30...150, id: \.self) { hr in
                            Text("\(hr)")
                                .font(AppTypography.timerDisplay)
                                .foregroundColor(AppColors.onBackground)
                                .tag(hr)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(height: 200)
                    
                    AppCard(style: .highlighted) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(AppColors.primary)
                            
                            Text("Set the lower limit for Zone 1 - Active Recovery. This will be the minimum heart rate for this zone.")
                                .font(AppTypography.callout)
                                .foregroundColor(AppColors.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    
                    Spacer()
                    
                    AppButton("SAVE", style: .primary) {
                        dismiss()
                    }
                    .padding(.horizontal, AppSpacing.screenMargin)
                    .padding(.bottom, AppSpacing.xxl)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.onBackground)
                            .font(AppTypography.headline)
                    }
                }
            }
        }
    }
}
