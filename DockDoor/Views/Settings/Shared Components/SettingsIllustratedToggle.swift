import AppKit
import SwiftUI

struct SettingsIllustratedToggle<Caption: View>: View {
    @Binding var isOn: Bool
    let title: LocalizedStringKey
    let imageName: String?
    @ViewBuilder var caption: Caption

    init(
        isOn: Binding<Bool>,
        title: LocalizedStringKey,
        imageName: String? = nil,
        @ViewBuilder caption: () -> Caption
    ) {
        _isOn = isOn
        self.title = title
        self.imageName = imageName
        self.caption = caption()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $isOn) { Text(title) }

                caption
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 20)
            }

            Spacer(minLength: 12)

            if let imageName {
                Image(imageName)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFill()
                    .frame(width: 280, height: 170)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

extension SettingsIllustratedToggle where Caption == EmptyView {
    init(isOn: Binding<Bool>, title: LocalizedStringKey, imageName: String? = nil) {
        self.init(isOn: isOn, title: title, imageName: imageName) { EmptyView() }
    }
}
