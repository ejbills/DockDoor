import Cocoa
import Defaults

// Holds logic related to precomputing image thumbnail sizes
extension WindowPreviewHoverContainer {
    struct WindowDimensions {
        let size: CGSize
        let maxDimensions: CGSize
    }

    static func calculateOverallMaxDimensions(
        windows: [WindowInfo],
        dockPosition: DockPosition,
        isWindowSwitcherActive: Bool,
        isMockPreviewActive: Bool,
        sharedPanelWindowSize: CGSize
    ) -> CGPoint {
        let pixelSize = Defaults[.previewPixelSize]
        let width = pixelSize
        let height = pixelSize / (16.0 / 9.0) // 16:9 aspect ratio
        return CGPoint(x: width, y: height)
    }

    static func precomputeWindowDimensions(
        windows: [WindowInfo],
        overallMaxDimensions: CGPoint,
        bestGuessMonitor: NSScreen
    ) -> [Int: WindowDimensions] {
        var dimensionsMap: [Int: WindowDimensions] = [:]

        let pixelSize = Defaults[.previewPixelSize]
        let width = pixelSize
        let height = pixelSize / (16.0 / 9.0) // 16:9 aspect ratio
        let fixedBoxSize = CGSize(width: width, height: height)

        let cardMaxFrameDimensions = CGSize(
            width: bestGuessMonitor.frame.width * 0.75,
            height: bestGuessMonitor.frame.height * 0.75
        )

        for (index, _) in windows.enumerated() {
            dimensionsMap[index] = WindowDimensions(
                size: fixedBoxSize,
                maxDimensions: cardMaxFrameDimensions
            )
        }
        return dimensionsMap
    }

    static func calculateSingleWindowDimensions(
        windowInfo: WindowInfo,
        overallMaxDimensions: CGPoint,
        bestGuessMonitor: NSScreen
    ) -> WindowDimensions {
        let pixelSize = Defaults[.previewPixelSize]
        let width = pixelSize
        let height = pixelSize / (16.0 / 9.0) // 16:9 aspect ratio
        let fixedBoxSize = CGSize(width: width, height: height)

        let cardMaxFrameDimensions = CGSize(
            width: bestGuessMonitor.frame.width * 0.75,
            height: bestGuessMonitor.frame.height * 0.75
        )

        return WindowDimensions(
            size: fixedBoxSize,
            maxDimensions: cardMaxFrameDimensions
        )
    }

    func getDimensions(for index: Int, dimensionsMap: [Int: WindowDimensions]) -> WindowDimensions {
        guard index >= 0, index < previewStateCoordinator.windows.count else {
            return WindowDimensions(
                size: CGSize(width: 100, height: 100),
                maxDimensions: CGSize(
                    width: bestGuessMonitor.frame.width * 0.75,
                    height: bestGuessMonitor.frame.height * 0.75
                )
            )
        }

        return dimensionsMap[index] ?? WindowDimensions(
            size: CGSize(width: 100, height: 100),
            maxDimensions: CGSize(
                width: bestGuessMonitor.frame.width * 0.75,
                height: bestGuessMonitor.frame.height * 0.75
            )
        )
    }
}
