import SwiftUI

struct AppButton: View {
    let title: String
    let style: Style
    let isLoading: Bool
    let action: () -> Void
    
    enum Style {
        case primary    // For main actions
        case secondary  // For secondary actions
        case destructive // For destructive actions
        case spotify    // For Spotify integration
    }
    
    init(
        _ title: String,
        style: Style = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        switch style {
        case .primary:
            Button(action: action) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    }
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppColors.primary)
            .clipShape(Capsule())
            .disabled(isLoading)
            
        case .secondary:
            Button(action: action) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.9)
                    }
                    Text(title)
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .clipShape(Capsule())
            .disabled(isLoading)
            
        case .destructive:
            Button(role: .destructive, action: action) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.9)
                    }
                    Text(title)
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .clipShape(Capsule())
            .disabled(isLoading)
            
        case .spotify:
            Button(action: action) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.9)
                    }
                    Text(title)
                        .foregroundColor(.black)
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppColors.spotify)
            .clipShape(Capsule())
            .disabled(isLoading)
        }
    }
}
