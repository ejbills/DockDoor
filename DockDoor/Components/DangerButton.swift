import SwiftUI

struct DangerButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label

    var body: some View {
        Button(role: .destructive, action: {
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
        .buttonStyle(.settings)
    }
}
