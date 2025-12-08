import Defaults
import SwiftUI

struct FullSizePreviewView: View {
    let windowInfo: WindowInfo
    let windowSize: CGSize
    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.enableLivePreview) var enableLivePreview

    var body: some View {
        let useLivePreview = enableLivePreview && !windowInfo.isMinimized && !windowInfo.isHidden

        Group {
            if useLivePreview {
                LivePreviewImage(windowID: windowInfo.id, fallbackImage: windowInfo.image)
                    .aspectRatio(windowSize, contentMode: .fit)
            } else if let image = windowInfo.image {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .aspectRatio(windowSize, contentMode: .fit)
            }
        }
    }
}
