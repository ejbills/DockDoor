import Cocoa
import Defaults

// Handles calculating rows and columns for flow container
extension WindowPreviewHoverContainer {
    func calculateOptimalLayout(windowDimensions: [Int: WindowDimensions], isHorizontal: Bool) -> (stackCount: Int, windowsPerStack: [Range<Int>]) {
        let activeWindowCount = windowStates.count

        guard activeWindowCount > 0 else {
            return (1, [0 ..< 0])
        }

        let previewWrap = Defaults[.previewWrap] > 0 ? Int(Defaults[.previewWrap]) : 4 // fallback to 4 if not set

        var ranges: [Range<Int>] = []
        var startIndex = 0
        while startIndex < activeWindowCount {
            let endIndex = min(startIndex + previewWrap, activeWindowCount)
            ranges.append(startIndex ..< endIndex)
            startIndex = endIndex
        }
        return (ranges.count, ranges)
    }

    private func redistributeEvenly(windowCount: Int, divisions: Int) -> (stackCount: Int, windowsPerStack: [Range<Int>]) {
        let baseCount = windowCount / divisions
        let remainder = windowCount % divisions

        var ranges: [Range<Int>] = []
        var startIndex = 0

        for division in 0 ..< divisions {
            let extraWindow = division < remainder ? 1 : 0
            let count = baseCount + extraWindow

            if count > 0 {
                ranges.append(startIndex ..< (startIndex + count))
                startIndex += count
            }
        }

        return (ranges.count, ranges)
    }
}
