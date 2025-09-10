import SwiftUI

struct BPMValueBox: View {
    let value: String
    let isEditable: Bool
    let action: (() -> Void)?
    
    init(value: String, isEditable: Bool = false, action: (() -> Void)? = nil) {
        self.value = value
        self.isEditable = isEditable
        self.action = action
    }
    
    var body: some View {
        Group {
            if isEditable, let action = action {
                Button(action: action) {
                    content
                }
            } else {
                content
            }
        }
    }
    
    private var content: some View {
        Text(value)
            .font(AppTypography.headline)
            .foregroundColor(isEditable ? AppColors.onBackground : AppColors.secondary)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(isEditable ? AppColors.tertiary : AppColors.surfaceSecondary)
            .cornerRadius(6)
    }
}