import Cocoa
import Defaults

// Handles calculating rows and columns for flow container
extension WindowPreviewHoverContainer {
    func calculateOptimalLayout(windowDimensions: [Int: WindowDimensions], isHorizontal: Bool) -> (stackCount: Int, windowsPerStack: [Range<Int>]) {
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

        // Calculate total vertical padding
        let totalVerticalPadding = outerPadding + flowStackPadding + additionalPadding
        let totalHorizontalPadding = outerPadding + flowStackPadding

        if isHorizontal {
            var rows: [[Int]] = [[]]
            var currentRowWidth: CGFloat = 0
            var currentRowIndex = 0
            let maxWidth = visibleFrame.width - totalHorizontalPadding
            let maxHeight = visibleFrame.height - totalVerticalPadding
            let rowHeight = maxWindowDimension.y + itemSpacing
            var hasExceededWidth = false

            // Calculate maximum allowed rows considering available height
            let availableHeight = maxHeight - itemSpacing // Subtract last row spacing
            let calculatedMaxRows = max(1, Int(floor(availableHeight / rowHeight)))
            let userMaxRows = Defaults[.maxRows]
            let effectiveMaxRows = userMaxRows > 0 ? min(Int(userMaxRows), calculatedMaxRows) : calculatedMaxRows

            for windowIndex in 0 ..< activeWindowCount {
                let windowWidth = windowDimensions[windowIndex]?.size.width ?? 0
                let newWidth = currentRowWidth + windowWidth + (currentRowWidth > 0 ? itemSpacing : 0)

                // Check if adding a window would exceed width or max rows
                if newWidth > maxWidth {
                    if hasExceededWidth {
                        let newRowCount = currentRowIndex + 2

                        // If we would exceed max rows, redistribute
                        if newRowCount > effectiveMaxRows {
                            return redistributeEvenly(windowCount: activeWindowCount, divisions: effectiveMaxRows)
                        }

                        // Start new row
                        currentRowIndex += 1
                        rows.append([])
                        currentRowWidth = windowWidth
                        hasExceededWidth = false
                    } else {
                        hasExceededWidth = true
                    }
                }

                rows[currentRowIndex].append(windowIndex)
                currentRowWidth = newWidth
            }

            // Double check we haven't exceeded max rows
            if rows.count > effectiveMaxRows {
                return redistributeEvenly(windowCount: activeWindowCount, divisions: effectiveMaxRows)
            }

            var ranges: [Range<Int>] = []
            var startIndex = 0

            for row in rows {
                if !row.isEmpty {
                    let endIndex = startIndex + row.count
                    ranges.append(startIndex ..< endIndex)
                    startIndex = endIndex
                }
            }

            return (ranges.count, ranges)

        } else {
            var columns: [[Int]] = [[]]
            var columnHeights: [CGFloat] = [0]
            var currentColumnIndex = 0
            let maxHeight = visibleFrame.height - totalVerticalPadding
            let maxWidth = visibleFrame.width - totalHorizontalPadding
            let columnWidth = maxWindowDimension.x + itemSpacing
            var hasExceededHeight = false

            // Calculate maximum allowed columns considering available width
            let availableWidth = maxWidth - itemSpacing // Subtract last column spacing
            let calculatedMaxColumns = max(1, Int(floor(availableWidth / columnWidth)))
            let userMaxColumns = Defaults[.maxColumns]
            let effectiveMaxColumns = userMaxColumns > 0 ? min(Int(userMaxColumns), calculatedMaxColumns) : calculatedMaxColumns

            for windowIndex in 0 ..< activeWindowCount {
                let windowHeight = (windowDimensions[windowIndex]?.size.height ?? 0)
                let newHeight = columnHeights[currentColumnIndex] + windowHeight + (columnHeights[currentColumnIndex] > 0 ? itemSpacing : 0)

                if newHeight > maxHeight {
                    if hasExceededHeight {
                        let newColumnCount = currentColumnIndex + 2

                        // If we would exceed max columns, redistribute
                        if newColumnCount > effectiveMaxColumns {
                            return redistributeEvenly(windowCount: activeWindowCount, divisions: effectiveMaxColumns)
                        }

                        // Start new column
                        currentColumnIndex += 1
                        columns.append([])
                        columnHeights.append(0)
                        hasExceededHeight = false
                    } else {
                        hasExceededHeight = true
                    }
                }

                columns[currentColumnIndex].append(windowIndex)
                columnHeights[currentColumnIndex] = newHeight
            }

            // Double check we haven't exceeded max columns
            if columns.count > effectiveMaxColumns {
                return redistributeEvenly(windowCount: activeWindowCount, divisions: effectiveMaxColumns)
            }

            var ranges: [Range<Int>] = []
            var startIndex = 0

            for column in columns {
                if !column.isEmpty {
                    let endIndex = startIndex + column.count
                    ranges.append(startIndex ..< endIndex)
                    startIndex = endIndex
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
