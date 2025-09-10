import SwiftUI

struct PickerModal: View {
    let title: String
    let selectedValue: Int
    let range: ClosedRange<Int>
    @Binding var isPresented: Bool
    let onValueChange: (Int) -> Void
    
    @State private var currentValue: Int
    @Environment(\.dismiss) private var dismiss
    
    init(
        title: String,
        selectedValue: Int,
        range: ClosedRange<Int>,
        isPresented: Binding<Bool>,
        onValueChange: @escaping (Int) -> Void
    ) {
        self.title = title
        self.selectedValue = selectedValue
        self.range = range
        self._isPresented = isPresented
        self.onValueChange = onValueChange
        self._currentValue = State(initialValue: selectedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
                // Title with proper top spacing
                Text(title)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.onBackground)
                    .tracking(1)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.lg)
                
                // Centered picker section
                Spacer()
                
                Picker(title, selection: $currentValue) {
                    ForEach(range, id: \.self) { value in
                        Text("\(value)")
                            .font(AppTypography.title3)
                            .foregroundColor(AppColors.onBackground)
                            .tag(value)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 200)
                .onChange(of: currentValue) {
                    onValueChange(currentValue)
                }
                
                Spacer()
                
                // Button with proper bottom spacing
                AppButton("DONE", style: .primary) {
                    dismiss()
                }
                .padding(.horizontal, AppSpacing.screenMargin)
                .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
        .onDisappear {
            isPresented = false
        }
    }
}
