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
        if Defaults[.allowDynamicImageSizing] {
            // Use the old dynamic sizing logic based on actual window aspect ratios
            let thickness = isMockPreviewActive ? 200 : sharedPanelWindowSize.height
            var maxWidth: CGFloat = 300 // Default/min
            var maxHeight: CGFloat = 300 // Default/min

            let orientationIsHorizontal: Bool = if isWindowSwitcherActive {
                true
            } else {
                dockPosition == .bottom || dockPosition == .cmdTab
            }
            let maxAspectRatio: CGFloat = 1.5

            for window in windows {
                if let cgImage = window.image {
                    let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
                    if orientationIsHorizontal {
                        let rawWidthBasedOnHeight = (cgSize.width * thickness) / cgSize.height
                        let widthBasedOnHeight = min(rawWidthBasedOnHeight, thickness * maxAspectRatio)
                        maxWidth = max(maxWidth, widthBasedOnHeight)
                        maxHeight = thickness
                    } else {
                        let rawHeightBasedOnWidth = (cgSize.height * thickness) / cgSize.width
                        let heightBasedOnWidth = min(rawHeightBasedOnWidth, thickness * maxAspectRatio)
                        maxHeight = max(maxHeight, heightBasedOnWidth)
                        maxWidth = thickness
                    }
                }
            }
            return CGPoint(x: max(1, maxWidth), y: max(1, maxHeight)) // Ensure positive dimensions
        } else {
            // Use fixed sizing from user settings
            let width = Defaults[.previewWidth]
            let height = Defaults[.previewHeight]
            return CGPoint(x: width, y: height)
        }
    }

    static func precomputeWindowDimensions(
        windows: [WindowInfo],
        overallMaxDimensions: CGPoint,
        bestGuessMonitor: NSScreen,
        dockPosition: DockPosition,
        isWindowSwitcherActive: Bool,
        effectiveMaxColumns: Int,
        effectiveMaxRows: Int
    ) -> [Int: WindowDimensions] {
        var dimensionsMap: [Int: WindowDimensions] = [:]

        if Defaults[.allowDynamicImageSizing] {
            let orientationIsHorizontal: Bool = if isWindowSwitcherActive {
                true
            } else {
                dockPosition == .bottom || dockPosition == .cmdTab
            }

            let windowChunks = createWindowChunks(
                totalWindows: windows.count,
                isHorizontal: orientationIsHorizontal,
                maxColumns: effectiveMaxColumns,
                maxRows: effectiveMaxRows
            )

            for (_, chunk) in windowChunks.enumerated() {
                var unifiedHeight: CGFloat = 0
                var unifiedWidth: CGFloat = 0

                if orientationIsHorizontal {
                    let thickness = overallMaxDimensions.y
                    for windowIndex in chunk {
                        guard windowIndex < windows.count,
                              let cgImage = windows[windowIndex].image else { continue }

                        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
                        let aspectRatio = originalSize.width / originalSize.height

                        let rawWidthAtThickness = thickness * aspectRatio
                        let widthAtThickness = min(rawWidthAtThickness, thickness * 1.5)

                        unifiedWidth = max(unifiedWidth, widthAtThickness)
                    }
                    unifiedHeight = thickness
                } else {
                    let thickness = overallMaxDimensions.x
                    for windowIndex in chunk {
                        guard windowIndex < windows.count,
                              let cgImage = windows[windowIndex].image else { continue }

                        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
                        let aspectRatio = originalSize.width / originalSize.height

                        let rawWidthAtThickness = thickness * aspectRatio
                        let widthAtThickness = min(rawWidthAtThickness, thickness * 1.5)

                        unifiedWidth = max(unifiedWidth, widthAtThickness)
                    }
                    unifiedWidth = thickness
                }

                let maxDims = CGSize(width: overallMaxDimensions.x, height: overallMaxDimensions.y)

                for windowIndex in chunk {
                    guard windowIndex < windows.count else { continue }

                    if windows[windowIndex].image != nil {
                        let windowSize = if orientationIsHorizontal {
                            CGSize(width: 0, height: max(unifiedHeight, 50))
                        } else {
                            CGSize(width: max(unifiedWidth, 50), height: 0)
                        }

                        dimensionsMap[windowIndex] = WindowDimensions(size: windowSize, maxDimensions: maxDims)
                    } else {
                        let fallbackSize = CGSize(width: min(300, overallMaxDimensions.x),
                                                  height: min(300, overallMaxDimensions.y))
                        dimensionsMap[windowIndex] = WindowDimensions(size: fallbackSize, maxDimensions: maxDims)
                    }
                }
            }
        } else {
            let width = Defaults[.previewWidth]
            let height = Defaults[.previewHeight]
            let fixedBoxSize = CGSize(width: width, height: height)
            let maxDims = CGSize(width: width, height: height)

            for (index, _) in windows.enumerated() {
                dimensionsMap[index] = WindowDimensions(size: fixedBoxSize, maxDimensions: maxDims)
            }
        }
        return dimensionsMap
    }

    static func calculateSingleWindowDimensions(
        windowInfo: WindowInfo,
        overallMaxDimensions: CGPoint,
        bestGuessMonitor: NSScreen
    ) -> WindowDimensions {
        let width = Defaults[.previewWidth]
        let height = Defaults[.previewHeight]
        let maxDims = CGSize(width: overallMaxDimensions.x, height: overallMaxDimensions.y)
        return WindowDimensions(size: CGSize(width: width, height: height), maxDimensions: maxDims)
    }

    func getDimensions(for index: Int, dimensionsMap: [Int: WindowDimensions]) -> WindowDimensions {
        let fallback = WindowDimensions(
            size: CGSize(width: 100, height: 100),
            maxDimensions: CGSize(width: 100, height: 100)
        )
        guard index >= 0, index < previewStateCoordinator.windows.count else {
            return fallback
        }
        return dimensionsMap[index] ?? fallback
    }

    // MARK: - Helper Functions

    /// Computes the actual rendered dimension (width for horizontal flow, height for vertical) of a single window card.
    /// Calculates the effective maximum columns and rows based on screen size and user settings
    /// - Parameters:
    ///   - bestGuessMonitor: The screen to calculate for
    ///   - overallMaxDimensions: The maximum preview dimensions (width and height)
    ///   - dockPosition: Current dock position
    ///   - isWindowSwitcherActive: Whether window switcher is active
    ///   - previewMaxColumns: User setting for max columns
    ///   - previewMaxRows: User setting for max rows
    ///   - switcherMaxRows: Max rows for window switcher
    ///   - totalItems: Total number of items to display
    /// - Returns: Tuple of (maxColumns, maxRows)
    static func calculateEffectiveMaxColumnsAndRows(
        bestGuessMonitor: NSScreen,
        overallMaxDimensions: CGPoint,
        dockPosition: DockPosition,
        isWindowSwitcherActive: Bool,
        previewMaxColumns: Int,
        previewMaxRows: Int,
        switcherMaxRows: Int,
        totalItems: Int? = nil,
        windows: [WindowInfo]? = nil
    ) -> (maxColumns: Int, maxRows: Int) {
        let screenWidth = bestGuessMonitor.frame.width * 0.75
        let screenHeight = bestGuessMonitor.frame.height * 0.75
        let itemSpacing: CGFloat = 24
        let globalPadding: CGFloat = 40

        let previewWidth = overallMaxDimensions.x
        let previewHeight = overallMaxDimensions.y

        let isHorizontalFlow: Bool = if isWindowSwitcherActive {
            true
        } else {
            dockPosition == .bottom || dockPosition == .cmdTab
        }

        let useGreedyPacking = Defaults[.allowDynamicImageSizing] && windows != nil
        var calculatedMaxColumns: Int
        var calculatedMaxRows: Int

        if useGreedyPacking, let windows {
            if isHorizontalFlow {
                let availableWidth = screenWidth - globalPadding
                var sum: CGFloat = 0
                var count = 0
                for window in windows {
                    let w: CGFloat = if let img = window.image {
                        min(overallMaxDimensions.y * (CGFloat(img.width) / CGFloat(img.height)), overallMaxDimensions.x)
                    } else {
                        overallMaxDimensions.x
                    }
                    let needed = w + (count > 0 ? itemSpacing : 0)
                    if sum + needed > availableWidth { break }
                    sum += needed
                    count += 1
                }
                calculatedMaxColumns = max(1, count)
                calculatedMaxRows = max(1, Int((screenHeight - globalPadding + itemSpacing) / (previewHeight + itemSpacing)))
            } else {
                let availableHeight = screenHeight - globalPadding
                var sum: CGFloat = 0
                var count = 0
                for window in windows {
                    let h: CGFloat = if let img = window.image {
                        min(overallMaxDimensions.x / (CGFloat(img.width) / CGFloat(img.height)), overallMaxDimensions.y)
                    } else {
                        overallMaxDimensions.y
                    }
                    let needed = h + (count > 0 ? itemSpacing : 0)
                    if sum + needed > availableHeight { break }
                    sum += needed
                    count += 1
                }
                calculatedMaxRows = max(1, count)
                calculatedMaxColumns = max(1, Int((screenWidth - globalPadding + itemSpacing) / (previewWidth + itemSpacing)))
            }
        } else {
            calculatedMaxColumns = max(1, Int((screenWidth - globalPadding + itemSpacing) / (previewWidth + itemSpacing)))
            calculatedMaxRows = max(1, Int((screenHeight - globalPadding + itemSpacing) / (previewHeight + itemSpacing)))
        }

        var effectiveMaxColumns: Int
        var effectiveMaxRows: Int

        if isWindowSwitcherActive {
            let isVertical = Defaults[.windowSwitcherScrollDirection] == .vertical
            if isVertical {
                // Vertical scroll: columns capped to screen, rows unlimited (scroll through them)
                effectiveMaxColumns = min(switcherMaxRows, calculatedMaxColumns)
                effectiveMaxRows = .max
                if let totalItems, totalItems <= effectiveMaxColumns {
                    effectiveMaxRows = 1
                }
            } else {
                // Horizontal scroll: fixed rows, items overflow horizontally
                effectiveMaxColumns = calculatedMaxColumns
                effectiveMaxRows = min(switcherMaxRows, calculatedMaxRows)
                if let totalItems, totalItems <= calculatedMaxColumns {
                    effectiveMaxRows = 1
                }
            }
        } else if dockPosition == .cmdTab {
            effectiveMaxColumns = calculatedMaxColumns
            effectiveMaxRows = 1
        } else if dockPosition == .bottom {
            effectiveMaxColumns = calculatedMaxColumns
            effectiveMaxRows = previewMaxRows
            if let totalItems, totalItems <= calculatedMaxColumns {
                effectiveMaxRows = 1
            }
        } else {
            let fullScreenColumns = max(1, Int((bestGuessMonitor.frame.width - globalPadding + itemSpacing) / (previewWidth + itemSpacing)))
            let conservativeHeight = bestGuessMonitor.frame.height * 0.85
            let fittingRows = max(1, Int((conservativeHeight - globalPadding + itemSpacing) / (previewHeight + itemSpacing)))
            let neededColumns = if let totalItems {
                Int(ceil(Double(totalItems) / Double(fittingRows)))
            } else {
                previewMaxColumns
            }
            effectiveMaxColumns = min(max(previewMaxColumns, neededColumns), fullScreenColumns)
            effectiveMaxRows = fittingRows
            if let totalItems, totalItems <= effectiveMaxColumns {
                effectiveMaxRows = 1
            }
        }

        return (effectiveMaxColumns, effectiveMaxRows)
    }

    /// Organizes items into rows/columns based on flow direction
    /// - Parameters:
    ///   - items: Array of items to chunk
    ///   - isHorizontal: If true, fills rows left-to-right; if false, fills columns top-to-bottom
    ///   - maxColumns: Maximum items per row or maximum columns
    ///   - maxRows: Maximum rows or maximum items per column
    ///   - reverse: If true, reverses layout based on direction of window preview
    /// - Returns: Array of chunks (rows or columns)
    static func chunkArray<T>(
        items: [T],
        isHorizontal: Bool,
        maxColumns: Int,
        maxRows: Int,
        reverse: Bool = false
    ) -> [[T]] {
        let totalItems = items.count

        guard totalItems > 0, maxColumns > 0, maxRows > 0 else {
            return []
        }

        var chunks: [[T]]

        if isHorizontal {
            let actualRowsNeeded = min(maxRows, Int(ceil(Double(totalItems) / Double(maxColumns))))
            let itemsPerRow = Int(ceil(Double(totalItems) / Double(actualRowsNeeded)))

            chunks = []
            var startIndex = 0

            for _ in 0 ..< actualRowsNeeded {
                guard startIndex < totalItems else { break }

                let endIndex = min(startIndex + itemsPerRow, totalItems)
                let rowItems = Array(items[startIndex ..< endIndex])

                if !rowItems.isEmpty {
                    chunks.append(rowItems)
                }

                startIndex = endIndex
            }
        } else {
            let actualColumnsNeeded = min(maxColumns, Int(ceil(Double(totalItems) / Double(maxRows))))
            let itemsPerColumn = Int(ceil(Double(totalItems) / Double(actualColumnsNeeded)))

            chunks = []
            var startIndex = 0

            for _ in 0 ..< actualColumnsNeeded {
                guard startIndex < totalItems else { break }

                let endIndex = min(startIndex + itemsPerColumn, totalItems)
                let columnItems = Array(items[startIndex ..< endIndex])

                if !columnItems.isEmpty {
                    chunks.append(columnItems)
                }

                startIndex = endIndex
            }
        }

        if reverse {
            chunks = chunks.reversed()
        }

        return chunks
    }

    /// Creates chunks of window indices organized by rows/columns based on flow direction
    private static func createWindowChunks(
        totalWindows: Int,
        isHorizontal: Bool,
        maxColumns: Int,
        maxRows: Int
    ) -> [[Int]] {
        let windowIndices = Array(0 ..< totalWindows)
        return chunkArray(
            items: windowIndices,
            isHorizontal: isHorizontal,
            maxColumns: maxColumns,
            maxRows: maxRows
        )
    }

    /// Navigates window switcher grid
    /// - Returns: New index after navigation
    static func navigateWindowSwitcher(
        from currentIndex: Int,
        direction: ArrowDirection,
        totalItems: Int,
        dockPosition: DockPosition,
        isWindowSwitcherActive: Bool
    ) -> Int {
        guard let coordinator = SharedPreviewWindowCoordinator.activeInstance?.windowSwitcherCoordinator else {
            let delta = (direction == .right || direction == .down) ? 1 : -1
            return (currentIndex + delta + totalItems) % totalItems
        }

        let isHorizontalFlow: Bool = if isWindowSwitcherActive {
            true
        } else {
            dockPosition.isHorizontalFlow
        }

        let maxColumns = coordinator.effectiveGridColumns
        let maxRows = coordinator.effectiveGridRows

        let shouldReverse = (dockPosition == .bottom || dockPosition == .right) && !isWindowSwitcherActive

        return navigateInGrid(
            from: currentIndex,
            direction: direction,
            totalItems: totalItems,
            isHorizontal: isHorizontalFlow,
            maxColumns: maxColumns,
            maxRows: maxRows,
            reverse: shouldReverse
        )
    }

    /// Navigates in a 2D grid
    /// - Returns: New flat index after navigation
    static func navigateInGrid(
        from currentIndex: Int,
        direction: ArrowDirection,
        totalItems: Int,
        isHorizontal: Bool,
        maxColumns: Int,
        maxRows: Int,
        reverse: Bool = false
    ) -> Int {
        guard totalItems > 0, currentIndex >= 0, currentIndex < totalItems else {
            return currentIndex
        }

        let items = Array(0 ..< totalItems)
        let chunks = chunkArray(items: items, isHorizontal: isHorizontal, maxColumns: maxColumns, maxRows: maxRows, reverse: reverse)

        var currentChunkIndex = 0
        var currentPositionInChunk = 0

        for (chunkIdx, chunk) in chunks.enumerated() {
            if let posInChunk = chunk.firstIndex(of: currentIndex) {
                currentChunkIndex = chunkIdx
                currentPositionInChunk = posInChunk
                break
            }
        }

        var targetChunkIndex = currentChunkIndex
        var targetPositionInChunk = currentPositionInChunk

        if isHorizontal {
            switch direction {
            case .left:
                targetPositionInChunk -= 1
                if targetPositionInChunk < 0 {
                    targetChunkIndex = (currentChunkIndex - 1 + chunks.count) % chunks.count
                    targetPositionInChunk = chunks[targetChunkIndex].count - 1
                }
            case .right:
                targetPositionInChunk += 1
                if targetPositionInChunk >= chunks[currentChunkIndex].count {
                    targetChunkIndex = (currentChunkIndex + 1) % chunks.count
                    targetPositionInChunk = 0
                }
            case .up:
                targetChunkIndex = (currentChunkIndex - 1 + chunks.count) % chunks.count
                targetPositionInChunk = min(currentPositionInChunk, chunks[targetChunkIndex].count - 1)
            case .down:
                targetChunkIndex = (currentChunkIndex + 1) % chunks.count
                targetPositionInChunk = min(currentPositionInChunk, chunks[targetChunkIndex].count - 1)
            }
        } else {
            switch direction {
            case .up:
                targetPositionInChunk -= 1
                if targetPositionInChunk < 0 {
                    targetChunkIndex = (currentChunkIndex - 1 + chunks.count) % chunks.count
                    targetPositionInChunk = chunks[targetChunkIndex].count - 1
                }
            case .down:
                targetPositionInChunk += 1
                if targetPositionInChunk >= chunks[currentChunkIndex].count {
                    targetChunkIndex = (currentChunkIndex + 1) % chunks.count
                    targetPositionInChunk = 0
                }
            case .left:
                targetChunkIndex = (currentChunkIndex - 1 + chunks.count) % chunks.count
                targetPositionInChunk = min(currentPositionInChunk, chunks[targetChunkIndex].count - 1)
            case .right:
                targetChunkIndex = (currentChunkIndex + 1) % chunks.count
                targetPositionInChunk = min(currentPositionInChunk, chunks[targetChunkIndex].count - 1)
            }
        }

        return chunks[targetChunkIndex][targetPositionInChunk]
    }
}
