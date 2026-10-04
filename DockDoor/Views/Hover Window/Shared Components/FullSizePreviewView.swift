import Defaults
import SwiftUI

struct FullSizePreviewView: View {
    let windowInfo: WindowInfo
    let windowSize: CGSize
    @Default(.uniformCardRadius) var uniformCardRadius
    @ObservedObject var previewStateCoordinator: PreviewStateCoordinator
    @Default(.enableLivePreview) var enableLivePreview
    @Default(.enableLivePreviewForDock) var enableLivePreviewForDock
    @Default(.dockLivePreviewQuality) var dockLivePreviewQuality
    @Default(.dockLivePreviewFrameRate) var dockLivePreviewFrameRate

    var body: some View {
        let useLivePreview = enableLivePreview && enableLivePreviewForDock && !previewStateCoordinator.stageManagerProtectionEnabled && !windowInfo.isMinimized && !windowInfo.isHidden

        Group {
            if useLivePreview {
                LivePreviewImage(windowID: windowInfo.id, fallbackImage: windowInfo.image, quality: dockLivePreviewQuality, frameRate: dockLivePreviewFrameRate)
                    .aspectRatio(windowSize, contentMode: .fit)
            } else if let image = windowInfo.image,
                      !previewStateCoordinator.stageManagerProtectionEnabled || windowInfo.stageManagerImageApproved
            {
                Image(decorative: image, scale: 1.0)
                    .resizable()
                    .aspectRatio(windowSize, contentMode: .fit)
            }
        }
    }
}
