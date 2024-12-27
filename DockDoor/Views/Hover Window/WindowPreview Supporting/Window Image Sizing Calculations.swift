//
//  Window Image Sizing Calculations.swift
//  DockDoor
//
//  Created by Ethan Bills on 12/26/24.
//

import Cocoa
 
// Holds logic related to precomputing image thumbnail sizes
extension WindowPreviewHoverContainer {
    struct WindowDimensions {
        let size: CGSize
        let maxDimensions: CGSize
    }

    func precomputeWindowDimensions() -> [Int: WindowDimensions] {
        var dimensionsMap: [Int: WindowDimensions] = [:]
        let maxAllowedWidth = maxWindowDimension.x
        let maxAllowedHeight = maxWindowDimension.y
        let calculatedMaxDimensions = CGSize(
            width: bestGuessMonitor.frame.width * 0.75,
            height: bestGuessMonitor.frame.height * 0.75
        )

        for (index, windowInfo) in windowStates.enumerated() {
            guard let cgImage = windowInfo.image else {
                dimensionsMap[index] = WindowDimensions(size: .zero, maxDimensions: calculatedMaxDimensions)
                continue
            }

            let cgSize = CGSize(width: cgImage.width, height: cgImage.height)
            let aspectRatio = cgSize.width / cgSize.height

            var targetWidth = maxAllowedWidth
            var targetHeight = targetWidth / aspectRatio

            if targetHeight > maxAllowedHeight {
                targetHeight = maxAllowedHeight
                targetWidth = aspectRatio * targetHeight
            }

            dimensionsMap[index] = WindowDimensions(
                size: CGSize(width: targetWidth, height: targetHeight),
                maxDimensions: calculatedMaxDimensions
            )
        }

        return dimensionsMap
    }

    // Helper method to get dimensions for a specific window
    func getDimensions(for index: Int, dimensionsMap: [Int: WindowDimensions]) -> WindowDimensions {
        dimensionsMap[index] ?? WindowDimensions(
            size: .zero,
            maxDimensions: CGSize(
                width: bestGuessMonitor.frame.width * 0.75,
                height: bestGuessMonitor.frame.height * 0.75
            )
        )
    }
}

