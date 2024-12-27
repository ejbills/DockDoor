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

        if isHorizontal {
            var rows: [[Int]] = [[]]
            var currentRowWidth: CGFloat = 0
            var currentRowIndex = 0
            let maxWidth = visibleFrame.width
            let maxHeight = visibleFrame.height
            let rowHeight = maxWindowDimension.y + 16 // Single row height including spacing
            var hasExceededWidth = false

            // Calculate maximum allowed rows considering user defaults
            let calculatedMaxRows = max(1, Int(maxHeight / rowHeight))
            let userMaxRows = Defaults[.maxRows]
            let effectiveMaxRows = userMaxRows > 0 ? min(Int(userMaxRows), calculatedMaxRows) : calculatedMaxRows

            for windowIndex in 0 ..< activeWindowCount {
                let windowWidth = windowDimensions[windowIndex]?.size.width ?? 0
                let newWidth = currentRowWidth + windowWidth + 16

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
                        currentRowWidth = windowWidth + 16
                        hasExceededWidth = false
                    } else {
                        hasExceededWidth = true
                    }
                }

                rows[currentRowIndex].append(windowIndex)
                currentRowWidth += windowWidth + 16
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
            let maxHeight = visibleFrame.height
            let maxWidth = visibleFrame.width
            let columnWidth = maxWindowDimension.x + 16
            var hasExceededHeight = false

            // Calculate maximum allowed columns considering user defaults
            let calculatedMaxColumns = max(1, Int(maxWidth / columnWidth))
            let userMaxColumns = Defaults[.maxColumns]
            let effectiveMaxColumns = userMaxColumns > 0 ? min(Int(userMaxColumns), calculatedMaxColumns) : calculatedMaxColumns

            for windowIndex in 0 ..< activeWindowCount {
                let windowHeight = (windowDimensions[windowIndex]?.size.height ?? 0) + 16
                let newHeight = columnHeights[currentColumnIndex] + windowHeight

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
                columnHeights[currentColumnIndex] += windowHeight
            }

            // Convert to ranges
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
