import Defaults
import SwiftUI

struct FullSizePreviewView: View {
    let windowInfo: WindowInfo
    let windowSize: CGSize
    @Default(.uniformCardRadius) var uniformCardRadius
    @ObservedObject var liveCapture = LiveWindowCapture.shared

    var body: some View {
        Group {
            let displayImage = (windowInfo.isMinimized || windowInfo.isHidden) ? windowInfo.image : (liveCapture.capturedImages[windowInfo.id] ?? windowInfo.image)
            if let image = displayImage {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .aspectRatio(windowSize, contentMode: .fit)
            }
        }
    }
}
