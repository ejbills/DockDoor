import SwiftUI

struct DangerButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    var color: Color = .red
    var small = false

    var body: some View {
        Button(action: {
            MessageUtil.showAlert(
                title: String(localized: "Confirm"),
                message: String(localized: "Are you sure you want to proceed?"),
                actions: [.ok, .cancel]
            ) { buttonAction in
                if buttonAction == .ok {
                    action()
                }
            }
        }) {
            label()
        }
        .buttonStyle(AccentButtonStyle(color: color, small: small))
    }
}
