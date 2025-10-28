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

            let orientationIsHorizontal = dockPosition == .bottom || dockPosition == .cmdTab || isWindowSwitcherActive
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
        previewMaxColumns: Int,
        previewMaxRows: Int,
        previewFixedDimensions: Bool,
        switcherMaxRows: Int
    ) -> [Int: WindowDimensions] {
        var dimensionsMap: [Int: WindowDimensions] = [:]

        let cardMaxFrameDimensions = CGSize(
            width: bestGuessMonitor.frame.width * 0.75,
            height: bestGuessMonitor.frame.height * 0.75
        )

        if Defaults[.allowDynamicImageSizing] {
            // Use row/column-aware dynamic sizing for unified UX experience
            let orientationIsHorizontal = dockPosition == .bottom || dockPosition == .cmdTab || isWindowSwitcherActive

            // Force a single row while in Cmd+Tab context, regardless of user row settings
            let effectiveMaxRows = (dockPosition == .cmdTab) ? 1 : (isWindowSwitcherActive ? switcherMaxRows : previewMaxRows)

            // Cmd+Tab doesn't do fixed dimensions
            let useFixedDimensions = (dockPosition == .cmdTab) ? false : previewFixedDimensions

            let windowChunks = createWindowChunks(
                totalWindows: windows.count,
                isHorizontal: orientationIsHorizontal,
                maxColumns: previewMaxColumns,
                maxRows: effectiveMaxRows,
                fixedDimensions: useFixedDimensions
            )

            // Process each chunk (row/column) to find unified dimensions
            for (_, chunk) in windowChunks.enumerated() {
                var unifiedHeight: CGFloat = 0
                var unifiedWidth: CGFloat = 0

                if orientationIsHorizontal {
                    // For horizontal flow: find the tallest window in this specific row
                    let thickness = overallMaxDimensions.y // This is the available height
                    for windowIndex in chunk {
                        guard windowIndex < windows.count,
                              let cgImage = windows[windowIndex].image else { continue }

                        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
                        let aspectRatio = originalSize.width / originalSize.height

                        // Calculate what width this window would need at the thickness height
                        let rawWidthAtThickness = thickness * aspectRatio
                        let widthAtThickness = min(rawWidthAtThickness, thickness * 1.5) // Max aspect ratio 1.5

                        unifiedWidth = max(unifiedWidth, widthAtThickness)
                    }
                    unifiedHeight = thickness // All windows in this row use the full thickness height
                } else {
                    // For vertical flow: find the widest window in this specific column
                    let thickness = overallMaxDimensions.x // This is the available width
                    for windowIndex in chunk {
                        guard windowIndex < windows.count,
                              let cgImage = windows[windowIndex].image else { continue }

                        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
                        let aspectRatio = originalSize.width / originalSize.height

                        // Calculate what width this window would need at the thickness width
                        let rawWidthAtThickness = thickness * aspectRatio
                        let widthAtThickness = min(rawWidthAtThickness, thickness * 1.5) // Max aspect ratio 1.5

                        unifiedWidth = max(unifiedWidth, widthAtThickness)
                    }
                    unifiedWidth = thickness // All windows in this column use the full thickness width
                }

                // Apply unified dimension constraint but let each window scale naturally
                for windowIndex in chunk {
                    guard windowIndex < windows.count else { continue }

                    if windows[windowIndex].image != nil {
                        let windowSize = if orientationIsHorizontal {
                            // For horizontal flow: unified height, let width scale naturally
                            CGSize(width: 0, height: max(unifiedHeight, 50)) // width = 0 means no constraint
                        } else {
                            // For vertical flow: unified width, let height scale naturally
                            CGSize(width: max(unifiedWidth, 50), height: 0) // height = 0 means no constraint
                        }

                        dimensionsMap[windowIndex] = WindowDimensions(
                            size: windowSize,
                            maxDimensions: cardMaxFrameDimensions
                        )
                    } else {
                        // Fallback for windows without images
                        let fallbackSize = CGSize(width: min(300, overallMaxDimensions.x),
                                                  height: min(300, overallMaxDimensions.y))
                        dimensionsMap[windowIndex] = WindowDimensions(
                            size: fallbackSize,
                            maxDimensions: cardMaxFrameDimensions
                        )
                    }
                }
            }
        } else {
            // Use fixed sizing from user settings
            let width = Defaults[.previewWidth]
            let height = Defaults[.previewHeight]
            let fixedBoxSize = CGSize(width: width, height: height)

            for (index, _) in windows.enumerated() {
                dimensionsMap[index] = WindowDimensions(
                    size: fixedBoxSize,
                    maxDimensions: cardMaxFrameDimensions
                )
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

    // MARK: - Helper Functions

    /// Creates chunks of window indices organized by rows/columns based on flow direction
    private static func createWindowChunks(
        totalWindows: Int,
        isHorizontal: Bool,
        maxColumns: Int,
        maxRows: Int,
        fixedDimensions: Bool
    ) -> [[Int]] {
        guard totalWindows > 0, maxColumns > 0, maxRows > 0 else { return [] }

        let windowIndices = Array(0 ..< totalWindows)

        if isHorizontal {
            // Horizontal flow: create rows
            if maxRows == 1 {
                return [windowIndices]
            }

            let itemsPerRow = fixedDimensions ? maxColumns : Int(ceil(Double(totalWindows) / Double(maxRows)))
            var chunks: [[Int]] = []
            var startIndex = 0

            for _ in 0 ..< maxRows {
                let endIndex = min(startIndex + itemsPerRow, totalWindows)
                if startIndex < totalWindows {
                    let rowItems = Array(windowIndices[startIndex ..< endIndex])
                    if !rowItems.isEmpty {
                        chunks.append(rowItems)
                    }
                    startIndex = endIndex
                }
                if startIndex >= totalWindows { break }
            }

            return chunks
        } else {
            // Vertical flow: create columns
            if maxColumns == 1 {
                return [windowIndices]
            }

            let itemsPerColumn = fixedDimensions ? maxRows : Int(ceil(Double(totalWindows) / Double(maxColumns)))
            var chunks: [[Int]] = []
            var startIndex = 0

            for _ in 0 ..< maxColumns {
                let endIndex = min(startIndex + itemsPerColumn, totalWindows)
                if startIndex < totalWindows {
                    let columnItems = Array(windowIndices[startIndex ..< endIndex])
                    if !columnItems.isEmpty {
                        chunks.append(columnItems)
                    }
                    startIndex = endIndex
                }
                if startIndex >= totalWindows { break }
            }

            return chunks
        }
    }
}
