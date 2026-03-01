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
        if Defaults[.allowDynamicImageSizing], !isWindowSwitcherActive {
            // Scale preview dimensions to match actual window aspect ratios (dock previews only)
            let thickness = isMockPreviewActive ? 200 : sharedPanelWindowSize.height
            var maxWidth: CGFloat = 300
            var maxHeight: CGFloat = 300

            let orientationIsHorizontal = dockPosition == .bottom || dockPosition == .cmdTab
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

    private static func computeRenderedDimension(
        image: CGImage,
        thickness: CGFloat,
        maxDimensions: CGSize,
        isHorizontal: Bool
    ) -> CGSize {
        let aspectRatio = CGFloat(image.width) / CGFloat(image.height)
        if isHorizontal {
            let width = min(thickness * aspectRatio, maxDimensions.width)
            return CGSize(width: width, height: thickness)
        } else {
            let height = min(thickness / aspectRatio, maxDimensions.height)
            return CGSize(width: thickness, height: height)
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

        if Defaults[.allowDynamicImageSizing], !isWindowSwitcherActive {
            let orientationIsHorizontal: Bool = dockPosition == .bottom || dockPosition == .cmdTab
            let maxDims = CGSize(width: overallMaxDimensions.x, height: overallMaxDimensions.y)
            let thickness: CGFloat = orientationIsHorizontal ? overallMaxDimensions.y : overallMaxDimensions.x

            for (index, window) in windows.enumerated() {
                if let cgImage = window.image {
                    let rendered = computeRenderedDimension(
                        image: cgImage,
                        thickness: thickness,
                        maxDimensions: maxDims,
                        isHorizontal: orientationIsHorizontal
                    )
                    let windowSize = if orientationIsHorizontal {
                        CGSize(width: rendered.width, height: max(rendered.height, 50))
                    } else {
                        CGSize(width: max(rendered.width, 50), height: rendered.height)
                    }
                    dimensionsMap[index] = WindowDimensions(size: windowSize, maxDimensions: maxDims)
                } else {
                    let fallbackSize = CGSize(width: min(300, overallMaxDimensions.x),
                                              height: min(300, overallMaxDimensions.y))
                    dimensionsMap[index] = WindowDimensions(size: fallbackSize, maxDimensions: maxDims)
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
        totalItems: Int? = nil
    ) -> (maxColumns: Int, maxRows: Int) {
        let screenWidth = bestGuessMonitor.frame.width * 0.75
        let screenHeight = bestGuessMonitor.frame.height * 0.75
        let itemSpacing = HoverContainerPadding.itemSpacing
        let globalPadding: CGFloat = 40

        let previewWidth = overallMaxDimensions.x
        let previewHeight = overallMaxDimensions.y

        let calculatedMaxColumns = max(1, Int((screenWidth - globalPadding + itemSpacing) / (previewWidth + itemSpacing)))
        let calculatedMaxRows = max(1, Int((screenHeight - globalPadding + itemSpacing) / (previewHeight + itemSpacing)))

        var effectiveMaxColumns: Int
        var effectiveMaxRows: Int

        if isWindowSwitcherActive {
            let isVertical = Defaults[.windowSwitcherScrollDirection] == .vertical
            if isVertical {
                effectiveMaxRows = calculatedMaxRows
                if let totalItems, totalItems <= calculatedMaxRows {
                    effectiveMaxColumns = 1
                } else {
                    effectiveMaxColumns = switcherMaxRows
                }
            } else {
                effectiveMaxColumns = calculatedMaxColumns
                if let totalItems, totalItems <= calculatedMaxColumns {
                    effectiveMaxRows = 1
                } else {
                    effectiveMaxRows = switcherMaxRows
                }
            }
        } else if dockPosition == .bottom || dockPosition == .cmdTab {
            effectiveMaxColumns = calculatedMaxColumns
            effectiveMaxRows = (dockPosition == .cmdTab) ? 1 : previewMaxRows
        } else {
            effectiveMaxColumns = previewMaxColumns
            effectiveMaxRows = calculatedMaxRows
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

        let bestGuessMonitor = NSScreen.main ?? NSScreen.screens.first!
        let isHorizontalFlow: Bool = if isWindowSwitcherActive {
            true
        } else {
            dockPosition.isHorizontalFlow
        }

        let (maxColumns, maxRows) = calculateEffectiveMaxColumnsAndRows(
            bestGuessMonitor: bestGuessMonitor,
            overallMaxDimensions: coordinator.overallMaxPreviewDimension,
            dockPosition: dockPosition,
            isWindowSwitcherActive: isWindowSwitcherActive,
            previewMaxColumns: Defaults[.previewMaxColumns],
            previewMaxRows: Defaults[.previewMaxRows],
            switcherMaxRows: Defaults[.switcherMaxRows],
            totalItems: totalItems
        )

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
