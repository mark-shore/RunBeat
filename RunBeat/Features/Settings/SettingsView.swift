import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var heartRateViewModel: HeartRateViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingRestingHRPicker = false
    @State private var showingMaxHRPicker = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // HR Settings Card
                    CompactHRSettings(
                        heartRateViewModel: heartRateViewModel,
                        showingRestingHRPicker: $showingRestingHRPicker,
                        showingMaxHRPicker: $showingMaxHRPicker
                    )
                    .padding(.horizontal, AppSpacing.screenMargin)
                    .padding(.top, AppSpacing.lg)
                    
                    // Heart Rate Zones Card
                    HeartRateZonesCard(heartRateViewModel: heartRateViewModel)
                        .padding(.horizontal, AppSpacing.screenMargin)
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
            PickerModal(
                title: "RESTING HR",
                selectedValue: heartRateViewModel.restingHR,
                range: 30...100,
                isPresented: $showingRestingHRPicker,
                onValueChange: { newValue in
                    heartRateViewModel.restingHR = newValue
                }
            )
        }
        .sheet(isPresented: $showingMaxHRPicker) {
            PickerModal(
                title: "MAX HR",
                selectedValue: heartRateViewModel.maxHR,
                range: 120...220,
                isPresented: $showingMaxHRPicker,
                onValueChange: { newValue in
                    heartRateViewModel.maxHR = newValue
                }
            )
        }
    }
}

struct ZonePickerConfig {
    let title: String
    let currentValue: Int
    let range: ClosedRange<Int>
    let onSave: (Int) -> Void
}

struct HeartRateZonesCard: View {
    @ObservedObject var heartRateViewModel: HeartRateViewModel
    @State private var activePickerConfig: ZonePickerConfig?
    
    private var zones: (Int, Int, Int, Int, Int, Int) {
        heartRateViewModel.currentZoneLimits
    }
    
    private var isInteractive: Bool {
        !heartRateViewModel.useAutoZones
    }
    
    var body: some View {
        AppCard {
            VStack(spacing: AppSpacing.md) {
                // Card title
                Text("Heart Rate Zones")
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.onBackground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Zone Calculation section with toggle
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Text("Zone Calculation")
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.onBackground)
                        
                        Spacer()
                        
                        HStack(spacing: AppSpacing.sm) {
                            Text("Auto")
                                .font(AppTypography.caption)
                                .foregroundColor(heartRateViewModel.useAutoZones ? AppColors.primary : AppColors.secondary)
                            
                            Toggle("", isOn: Binding(
                                get: { !heartRateViewModel.useAutoZones },
                                set: { heartRateViewModel.useAutoZones = !$0 }
                            ))
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                            .scaleEffect(0.8)
                            
                            Text("Manual")
                                .font(AppTypography.caption)
                                .foregroundColor(!heartRateViewModel.useAutoZones ? AppColors.primary : AppColors.secondary)
                        }
                    }
                    
                    Text("Your HR zones are calculated using the heart rate reserve formula. You can manually update your HR zone ranges.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                // Table header
                HStack {
                    Text("ZONE")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    Text("MIN")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    Text("MAX")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)
                        .frame(width: 80, alignment: .leading)
                }
                
                // Zone rows (5 to 1, reverse order)
                let zoneColors: [Color] = [AppColors.zone1, AppColors.zone2, AppColors.zone3, AppColors.zone4, AppColors.zone5]
                let zoneRanges = [
                    (zones.0, zones.1), // Zone 1: zone1Lower to zone1Upper
                    (zones.1 + 1, zones.2), // Zone 2: zone1Upper+1 to zone2Upper
                    (zones.2 + 1, zones.3), // Zone 3: zone2Upper+1 to zone3Upper
                    (zones.3 + 1, zones.4), // Zone 4: zone3Upper+1 to zone4Upper
                    (zones.4 + 1, zones.5)  // Zone 5: zone4Upper+1 to zone5Upper
                ]
                
                ForEach(0..<5, id: \.self) { index in
                    let zoneNumber = 5 - index
                    let zoneRange = zoneRanges[4-index]
                    let zoneColor = zoneColors[4-index]
                    
                    HStack {
                        // Zone indicator column
                        HStack {
                            Circle()
                                .fill(zoneColor)
                                .frame(width: 12, height: 12)
                            
                            Text("Zone \(zoneNumber)")
                                .font(AppTypography.headline)
                                .foregroundColor(AppColors.onBackground)
                        }
                        .frame(width: 80, alignment: .leading)
                        
                        Spacer()
                        
                        // Min value column
                        HStack(spacing: AppSpacing.xs) {
                            let minEditable = isInteractive // All zones min values are editable in manual mode
                            
                            BPMValueBox(
                                value: "\(zoneRange.0)",
                                isEditable: minEditable,
                                action: minEditable ? { openPickerForZone(zoneNumber, isLower: true, currentValue: zoneRange.0) } : nil
                            )
                            
                            Text("bpm")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary)
                        }
                        .frame(width: 80, alignment: .leading)
                        
                        Spacer()
                        
                        // Max value column
                        HStack(spacing: AppSpacing.xs) {
                            let isZone5Upper = zoneNumber == 5
                            let maxEditable = isInteractive && !isZone5Upper
                            
                            BPMValueBox(
                                value: "\(zoneRange.1)",
                                isEditable: maxEditable,
                                action: maxEditable ? { openPickerForZone(zoneNumber, isLower: false, currentValue: zoneRange.1) } : nil
                            )
                            
                            Text("bpm")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary)
                        }
                        .frame(width: 80, alignment: .leading)
                    }
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .sheet(item: $activePickerConfig) { config in
            PickerModal(
                title: config.title,
                selectedValue: config.currentValue,
                range: config.range,
                isPresented: .constant(true),
                onValueChange: config.onSave
            )
        }
    }
    
    private func openPickerForZone(_ zoneNumber: Int, isLower: Bool, currentValue: Int) {
        let config: ZonePickerConfig
        
        if isLower {
            // Lower limits - editing these adjusts the previous zone's upper limit
            switch zoneNumber {
            case 1:
                config = ZonePickerConfig(
                    title: "ZONE 1 LOWER",
                    currentValue: currentValue,
                    range: 30...heartRateViewModel.zone1Upper - 5, // Min 5 BPM zone width
                    onSave: { newValue in
                        heartRateViewModel.zone1Lower = newValue
                    }
                )
            case 2:
                config = ZonePickerConfig(
                    title: "ZONE 2 LOWER",
                    currentValue: currentValue,
                    range: heartRateViewModel.zone1Lower + 5...heartRateViewModel.zone2Upper - 5,
                    onSave: { newValue in
                        // Zone 2 lower = newValue, so Zone 1 upper = newValue - 1
                        heartRateViewModel.zone1Upper = newValue - 1
                    }
                )
            case 3:
                config = ZonePickerConfig(
                    title: "ZONE 3 LOWER",
                    currentValue: currentValue,
                    range: heartRateViewModel.zone1Upper + 5...heartRateViewModel.zone3Upper - 5,
                    onSave: { newValue in
                        // Zone 3 lower = newValue, so Zone 2 upper = newValue - 1
                        heartRateViewModel.zone2Upper = newValue - 1
                    }
                )
            case 4:
                config = ZonePickerConfig(
                    title: "ZONE 4 LOWER",
                    currentValue: currentValue,
                    range: heartRateViewModel.zone2Upper + 5...heartRateViewModel.zone4Upper - 5,
                    onSave: { newValue in
                        // Zone 4 lower = newValue, so Zone 3 upper = newValue - 1
                        heartRateViewModel.zone3Upper = newValue - 1
                    }
                )
            case 5:
                config = ZonePickerConfig(
                    title: "ZONE 5 LOWER",
                    currentValue: currentValue,
                    range: heartRateViewModel.zone3Upper + 5...heartRateViewModel.maxHR - 5,
                    onSave: { newValue in
                        // Zone 5 lower = newValue, so Zone 4 upper = newValue - 1
                        heartRateViewModel.zone4Upper = newValue - 1
                    }
                )
            default:
                return
            }
        } else {
            // Upper limits - editing these automatically adjusts next zone's lower limit
            switch zoneNumber {
            case 1:
                config = ZonePickerConfig(
                    title: "ZONE 1 UPPER",
                    currentValue: currentValue,
                    range: heartRateViewModel.zone1Lower + 5...heartRateViewModel.zone2Upper - 5,
                    onSave: { newValue in
                        heartRateViewModel.zone1Upper = newValue
                        // Zone 2 lower automatically becomes newValue + 1 (handled by currentZoneLimits)
                    }
                )
            case 2:
                config = ZonePickerConfig(
                    title: "ZONE 2 UPPER",
                    currentValue: currentValue,
                    range: heartRateViewModel.zone1Upper + 5...heartRateViewModel.zone3Upper - 5,
                    onSave: { newValue in
                        heartRateViewModel.zone2Upper = newValue
                        // Zone 3 lower automatically becomes newValue + 1 (handled by currentZoneLimits)
                    }
                )
            case 3:
                config = ZonePickerConfig(
                    title: "ZONE 3 UPPER",
                    currentValue: currentValue,
                    range: heartRateViewModel.zone2Upper + 5...heartRateViewModel.zone4Upper - 5,
                    onSave: { newValue in
                        heartRateViewModel.zone3Upper = newValue
                        // Zone 4 lower automatically becomes newValue + 1 (handled by currentZoneLimits)
                    }
                )
            case 4:
                config = ZonePickerConfig(
                    title: "ZONE 4 UPPER",
                    currentValue: currentValue,
                    range: heartRateViewModel.zone3Upper + 5...heartRateViewModel.maxHR,
                    onSave: { newValue in
                        heartRateViewModel.zone4Upper = newValue
                        // Zone 5 lower automatically becomes newValue + 1 (handled by currentZoneLimits)
                    }
                )
            default:
                return
            }
        }
        
        activePickerConfig = config
    }
}

extension ZonePickerConfig: Identifiable {
    var id: String { title }
}

struct CompactHRSettings: View {
    @ObservedObject var heartRateViewModel: HeartRateViewModel
    @Binding var showingRestingHRPicker: Bool
    @Binding var showingMaxHRPicker: Bool
    
    var body: some View {
        AppCard {
            VStack(spacing: AppSpacing.md) {
                // Card title
                Text("Heart Rate Settings")
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.onBackground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Resting HR row
                HStack {
                    Text("Resting HR")
                        .font(AppTypography.callout)
                        .foregroundColor(AppColors.onBackground)
                    
                    Spacer()
                    
                    HStack(spacing: AppSpacing.xs) {
                        BPMValueBox(
                            value: "\(heartRateViewModel.restingHR)",
                            isEditable: true,
                            action: { showingRestingHRPicker = true }
                        )
                        
                        Text("bpm")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                }
                .padding(.vertical, AppSpacing.xs)
                
                // Max HR row
                HStack {
                    Text("Maximum HR")
                        .font(AppTypography.callout)
                        .foregroundColor(AppColors.onBackground)
                    
                    Spacer()
                    
                    HStack(spacing: AppSpacing.xs) {
                        BPMValueBox(
                            value: "\(heartRateViewModel.maxHR)",
                            isEditable: true,
                            action: { showingMaxHRPicker = true }
                        )
                        
                        Text("bpm")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                }
                .padding(.vertical, AppSpacing.xs)
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
