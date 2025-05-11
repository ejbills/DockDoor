import Cocoa
import Defaults

// Handles calculating rows and columns for flow container
extension WindowPreviewHoverContainer {
    func calculateOptimalLayout(windowDimensions: [Int: WindowDimensions], isHorizontal: Bool, wrap: Int) -> (stackCount: Int, windowsPerStack: [Range<Int>]) {
        let activeWindowCount = windowStates.count

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
            if windowSwitcherCoordinator.windowSwitcherActive {
                return 50
            } else if showAppName {
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
            let rowHeight = maxWindowDimension.y + itemSpacing
            let availableHeight = maxHeight - itemSpacing

            // Calculate maximum allowed rows
            let calculatedMaxRows = max(1, Int(floor(availableHeight / rowHeight)))
            let userMaxRows = wrap
            let effectiveMaxRows = userMaxRows > 0 ? min(Int(userMaxRows), calculatedMaxRows) : calculatedMaxRows

            // Calculate optimal number of rows based on window widths and available space
            var totalWidthNeeded: CGFloat = 0
            var maxWindowWidth: CGFloat = 0

            for windowIndex in 0 ..< activeWindowCount {
                let width = windowDimensions[windowIndex]?.size.width ?? 0
                totalWidthNeeded += width + (totalWidthNeeded > 0 ? itemSpacing : 0)
                maxWindowWidth = max(maxWindowWidth, width)
            }

            let avgWindowsPerRow = max(2, CGFloat(activeWindowCount) / CGFloat(effectiveMaxRows))
            let optimalRows = max(min(effectiveMaxRows,
                                      Int(ceil(totalWidthNeeded / maxWidth))),
                                  Int(ceil(CGFloat(activeWindowCount) / avgWindowsPerRow)))

            let targetWindowsPerRow = Int(floor(CGFloat(activeWindowCount) / CGFloat(optimalRows)))

            var rows: [[Int]] = [[]]
            var currentRowWidth: CGFloat = 0
            var currentRowIndex = 0
            var currentRowCount = 0

            for windowIndex in 0 ..< activeWindowCount {
                let windowWidth = windowDimensions[windowIndex]?.size.width ?? 0
                let newWidth = currentRowWidth + windowWidth + (currentRowWidth > 0 ? itemSpacing : 0)

                let isLastRow = currentRowIndex == effectiveMaxRows - 1
                let shouldStartNewRow = newWidth > maxWidth || (!isLastRow && currentRowCount >= targetWindowsPerRow)

                if shouldStartNewRow {
                    if currentRowIndex + 1 >= effectiveMaxRows {
                        return redistributeEvenly(windowCount: activeWindowCount, divisions: effectiveMaxRows)
                    }

                    currentRowIndex += 1
                    rows.append([])
                    currentRowWidth = windowWidth
                    currentRowCount = 1
                } else {
                    currentRowWidth = newWidth
                    currentRowCount += 1
                }

                rows[currentRowIndex].append(windowIndex)
            }

            var ranges: [Range<Int>] = []
            var startIndex = 0

            for row in rows {
                if !row.isEmpty {
                    ranges.append(startIndex ..< (startIndex + row.count))
                    startIndex += row.count
                }
            }

            return (ranges.count, ranges)

        } else {
            let maxHeight = visibleFrame.height - totalVerticalPadding
            let maxWidth = visibleFrame.width - totalHorizontalPadding
            let columnWidth = maxWindowDimension.x + itemSpacing
            let availableWidth = maxWidth - itemSpacing

            let calculatedMaxColumns = max(1, Int(floor(availableWidth / columnWidth)))
            let userMaxColumns = wrap
            let effectiveMaxColumns = userMaxColumns > 0 ? min(Int(userMaxColumns), calculatedMaxColumns) : calculatedMaxColumns

            var totalHeightNeeded: CGFloat = 0
            var maxWindowHeight: CGFloat = 0

            for windowIndex in 0 ..< activeWindowCount {
                let height = windowDimensions[windowIndex]?.size.height ?? 0
                totalHeightNeeded += height + (totalHeightNeeded > 0 ? itemSpacing : 0)
                maxWindowHeight = max(maxWindowHeight, height)
            }

            let avgWindowsPerColumn = max(2, CGFloat(activeWindowCount) / CGFloat(effectiveMaxColumns))
            let optimalColumns = max(min(effectiveMaxColumns,
                                         Int(ceil(totalHeightNeeded / maxHeight))),
                                     Int(ceil(CGFloat(activeWindowCount) / avgWindowsPerColumn)))

            let targetWindowsPerColumn = Int(floor(CGFloat(activeWindowCount) / CGFloat(optimalColumns)))

            var columns: [[Int]] = [[]]
            var columnHeights: [CGFloat] = [0]
            var currentColumnIndex = 0
            var currentColumnCount = 0

            for windowIndex in 0 ..< activeWindowCount {
                let windowHeight = windowDimensions[windowIndex]?.size.height ?? 0
                let newHeight = columnHeights[currentColumnIndex] + windowHeight + (columnHeights[currentColumnIndex] > 0 ? itemSpacing : 0)

                let isLastColumn = currentColumnIndex == effectiveMaxColumns - 1
                let shouldStartNewColumn = newHeight > maxHeight || (!isLastColumn && currentColumnCount >= targetWindowsPerColumn)

                if shouldStartNewColumn {
                    if currentColumnIndex + 1 >= effectiveMaxColumns {
                        return redistributeEvenly(windowCount: activeWindowCount, divisions: effectiveMaxColumns)
                    }

                    currentColumnIndex += 1
                    columns.append([])
                    columnHeights.append(0)
                    columnHeights[currentColumnIndex] = windowHeight
                    currentColumnCount = 1
                } else {
                    columnHeights[currentColumnIndex] = newHeight
                    currentColumnCount += 1
                }

                columns[currentColumnIndex].append(windowIndex)
            }

            var ranges: [Range<Int>] = []
            var startIndex = 0

            for column in columns {
                if !column.isEmpty {
                    ranges.append(startIndex ..< (startIndex + column.count))
                    startIndex += column.count
                }
            }

            return (ranges.count, ranges)
        }
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
