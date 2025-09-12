import SwiftUI

struct AppToggle: View {
    @Binding var isOn: Bool
    let label: String?
    
    init(_ label: String? = nil, isOn: Binding<Bool>) {
        self.label = label
        self._isOn = isOn
    }
    
    var body: some View {
        Toggle(label ?? "", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
            .scaleEffect(0.8)
    }
}