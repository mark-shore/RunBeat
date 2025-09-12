import SwiftUI

struct AppBackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: AppIcons.back)
                .font(AppTypography.title2)
                .foregroundColor(AppColors.onBackground)
        }
    }
}

#Preview {
    AppBackButton {
        // Preview action
    }
    .preferredColorScheme(.dark)
}