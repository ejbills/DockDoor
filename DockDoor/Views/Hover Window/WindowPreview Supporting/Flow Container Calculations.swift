import Cocoa
import Defaults

// Handles calculating rows and columns for flow container
extension WindowPreviewHoverContainer {
    func calculateOptimalLayout(
        windowDimensions: [Int: WindowDimensions],
        isHorizontal: Bool,
        wrap: Int,
        maxDimensionForLayout: CGPoint
    ) -> (stackCount: Int, windowsPerStack: [Range<Int>]) {
        let activeWindowCount = previewStateCoordinator.windows.count

        guard activeWindowCount > 0 else {
            return (1, [0 ..< 0])
        }

        let visibleFrame = bestGuessMonitor.visibleFrame

        // Container padding
        let outerPadding: CGFloat = 48
        let flowStackPadding: CGFloat = 40
        let itemSpacing: CGFloat = 16

        // Additional padding based on mode
        let additionalPadding: CGFloat = {
            if previewStateCoordinator.windowSwitcherActive {
                return 50
            } else if showAppTitleData {
                switch appNameStyle {
                case .default: return 25
                case .popover: return 30
                case .shadowed: return 25
                }
            }
            return 0
        }()

        let totalVerticalPadding = outerPadding + flowStackPadding + additionalPadding
        let totalHorizontalPadding = outerPadding + flowStackPadding

        if isHorizontal {
            let maxWidth = visibleFrame.width - totalHorizontalPadding
            let maxHeight = visibleFrame.height - totalVerticalPadding

            // Calculate actual window height from window dimensions instead of using maxDimensionForLayout
            var actualMaxWindowHeight: CGFloat = 0
            for windowIndex in 0 ..< activeWindowCount {
                let height = windowDimensions[windowIndex]?.size.height ?? maxDimensionForLayout.y
                actualMaxWindowHeight = max(actualMaxWindowHeight, height)
            }

            // First row: actualMaxWindowHeight
            // Subsequent rows: itemSpacing + actualMaxWindowHeight each
            let calculatedMaxRows: Int
            if actualMaxWindowHeight > maxHeight {
                calculatedMaxRows = 1 // Can't even fit one row properly
            } else {
                let remainingHeight = maxHeight - actualMaxWindowHeight
                let additionalRows = Int(floor(remainingHeight / (actualMaxWindowHeight + itemSpacing)))
                calculatedMaxRows = 1 + additionalRows
            }

            let userMaxRows = wrap
            let effectiveMaxRows = userMaxRows > 0 ? min(Int(userMaxRows), calculatedMaxRows) : calculatedMaxRows

            // Calculate total width needed for all windows
            var totalWidthNeeded: CGFloat = 0
            for windowIndex in 0 ..< activeWindowCount {
                let width = windowDimensions[windowIndex]?.size.width ?? 0
                totalWidthNeeded += width + (windowIndex > 0 ? itemSpacing : 0)
            }

            // Determine optimal number of rows
            let optimalRows: Int
            if totalWidthNeeded <= maxWidth {
                // All windows fit in one row
                optimalRows = 1
            } else {
                // Calculate how many rows we need based on available space
                let minRowsNeeded = Int(ceil(totalWidthNeeded / maxWidth))
                optimalRows = max(1, min(effectiveMaxRows, minRowsNeeded))
            }

            // Use even distribution for better balance
            return redistributeEvenly(windowCount: activeWindowCount, divisions: optimalRows)

        } else { // Vertical Flow
            let maxHeight = visibleFrame.height - totalVerticalPadding
            let maxWidth = visibleFrame.width - totalHorizontalPadding

            // Calculate actual window width from window dimensions instead of using maxDimensionForLayout
            var actualMaxWindowWidth: CGFloat = 0
            for windowIndex in 0 ..< activeWindowCount {
                let width = windowDimensions[windowIndex]?.size.width ?? maxDimensionForLayout.x
                actualMaxWindowWidth = max(actualMaxWindowWidth, width)
            }

            let calculatedMaxColumns: Int
            if actualMaxWindowWidth > maxWidth {
                calculatedMaxColumns = 1 // Can't even fit one column properly
            } else {
                let remainingWidth = maxWidth - actualMaxWindowWidth
                let additionalColumns = Int(floor(remainingWidth / (actualMaxWindowWidth + itemSpacing)))
                calculatedMaxColumns = 1 + additionalColumns
            }

            let userMaxColumns = wrap
            let effectiveMaxColumns = userMaxColumns > 0 ? min(Int(userMaxColumns), calculatedMaxColumns) : calculatedMaxColumns

            // Calculate total height needed for all windows
            var totalHeightNeeded: CGFloat = 0
            for windowIndex in 0 ..< activeWindowCount {
                let height = windowDimensions[windowIndex]?.size.height ?? 0
                totalHeightNeeded += height + (windowIndex > 0 ? itemSpacing : 0)
            }

            // Determine optimal number of columns
            let optimalColumns: Int
            if totalHeightNeeded <= maxHeight {
                // All windows fit in one column
                optimalColumns = 1
            } else {
                // Calculate how many columns we need based on available space
                let minColumnsNeeded = Int(ceil(totalHeightNeeded / maxHeight))
                optimalColumns = max(1, min(effectiveMaxColumns, minColumnsNeeded))
            }

            // Use even distribution for better balance
            return redistributeEvenly(windowCount: activeWindowCount, divisions: optimalColumns)
        }
    }

    private func redistributeEvenly(windowCount: Int, divisions: Int) -> (stackCount: Int, windowsPerStack: [Range<Int>]) {
        guard divisions > 0 else { // Prevent division by zero
            if windowCount > 0 { return (1, [0 ..< windowCount]) }
            return (0, [])
        }
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
        // If no ranges were created but there are windows (e.g. windowCount < divisions, baseCount is 0 for some), ensure all windows are covered.
        if ranges.isEmpty, windowCount > 0 {
            return (1, [0 ..< windowCount])
        }

        return (ranges.count > 0 ? ranges.count : 1, ranges)
    }
}
