//
//  Untitled.swift
//  DockDoor
//
//  Created by Ethan Bills on 12/26/24.
//

import Cocoa

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

            for windowIndex in 0 ..< activeWindowCount {
                let windowWidth = windowDimensions[windowIndex]?.size.width ?? 0
                let newWidth = currentRowWidth + windowWidth + 16

                // Check if adding a row would exceed total available height
                if newWidth > maxWidth {
                    if hasExceededWidth {
                        let newRowCount = currentRowIndex + 2 // Current + new one we'd need
                        let totalHeightNeeded = CGFloat(newRowCount) * rowHeight

                        if totalHeightNeeded > maxHeight {
                            // If we can't fit another row, redistribute across available height
                            let optimalRows = max(1, Int(maxHeight / rowHeight))
                            return redistributeEvenly(windowCount: activeWindowCount, divisions: optimalRows)
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

            for windowIndex in 0 ..< activeWindowCount {
                let windowHeight = (windowDimensions[windowIndex]?.size.height ?? 0) + 16
                let newHeight = columnHeights[currentColumnIndex] + windowHeight

                if newHeight > maxHeight {
                    if hasExceededHeight {
                        // Check if adding a new column would exceed screen width
                        let totalColumns = currentColumnIndex + 2
                        let totalWidthNeeded = CGFloat(totalColumns) * columnWidth

                        if totalWidthNeeded > maxWidth {
                            let optimalColumns = max(1, Int(maxWidth / columnWidth))
                            return redistributeEvenly(windowCount: activeWindowCount, divisions: optimalColumns)
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
