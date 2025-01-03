import Defaults
import SwiftUI

struct FullSizePreviewView: View {
    let windowInfo: WindowInfo
    let windowSize: CGSize
    @Default(.uniformCardRadius) var uniformCardRadius

    var body: some View {
        Group {
            if let image = windowInfo.image {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .aspectRatio(windowSize, contentMode: .fit)
                    .modifier(FluidGradientBorder(cornerRadius: uniformCardRadius ? 12 : 0, lineWidth: 2))
            }
        }
        .clipShape(uniformCardRadius ? AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous)) : AnyShape(Rectangle()))
    }
}
