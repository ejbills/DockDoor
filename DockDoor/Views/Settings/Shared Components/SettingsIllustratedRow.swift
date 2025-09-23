import SwiftUI

struct SettingsIllustratedRow<Content: View>: View {
    let imageName: String?
    let content: Content

    init(imageName: String? = nil, @ViewBuilder content: () -> Content) {
        self.imageName = imageName
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                content
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
