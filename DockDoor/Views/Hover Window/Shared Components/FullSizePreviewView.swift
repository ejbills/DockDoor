import Defaults
import SwiftUI

struct FullSizePreviewView: View {
    let windowInfo: WindowInfo
    let windowSize: CGSize
    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.enableLivePreview) var enableLivePreview
    @Default(.enableLivePreviewForDock) var enableLivePreviewForDock
    @Default(.dockLivePreviewQuality) var dockLivePreviewQuality
    @Default(.dockLivePreviewFrameRate) var dockLivePreviewFrameRate

    var body: some View {
        let useLivePreview = enableLivePreview && enableLivePreviewForDock && !windowInfo.isMinimized && !windowInfo.isHidden

        Group {
            if useLivePreview {
                LivePreviewImage(windowID: windowInfo.id, fallbackImage: windowInfo.image, quality: dockLivePreviewQuality, frameRate: dockLivePreviewFrameRate)
                    .aspectRatio(windowSize, contentMode: .fit)
            } else if let image = windowInfo.image {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .aspectRatio(windowSize, contentMode: .fit)
            }
        }
    }
}
