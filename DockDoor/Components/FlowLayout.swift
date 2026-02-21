import SwiftUI

final class GridInfoRef {
    private(set) var lines: [[Int]] = []
    private(set) var isHorizontal: Bool = true

    func update(lines: [[Int]], isHorizontal: Bool) {
        self.lines = lines
        self.isHorizontal = isHorizontal
    }
}

struct FlowLayout: Layout {
    var isHorizontal: Bool
    var spacing: CGFloat
    var maxItemsPerLine: Int
    var reverseLines: Bool
    var gridInfoRef: GridInfoRef?
    var maxPrimaryDimension: CGFloat = .infinity

    struct CacheData {
        var lines: [[Int]]
        var sizes: [CGSize]
    }

    func makeCache(subviews: Subviews) -> CacheData {
        CacheData(lines: [], sizes: [])
    }

    func updateCache(_ cache: inout CacheData, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let sizes = cache.sizes.isEmpty ? subviews.map { $0.sizeThatFits(.unspecified) } : cache.sizes

        let proposed = isHorizontal
            ? (proposal.width ?? .infinity)
            : (proposal.height ?? .infinity)
        let available = min(proposed, maxPrimaryDimension)

        let lines = computeLines(sizes: sizes, available: available)
        cache.lines = lines

        let visualLines = reverseLines ? lines.reversed().map { $0 } : lines
        gridInfoRef?.update(lines: visualLines, isHorizontal: isHorizontal)

        return totalSize(lines: lines, sizes: sizes)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        guard !subviews.isEmpty else { return }

        let sizes = cache.sizes.isEmpty ? subviews.map { $0.sizeThatFits(.unspecified) } : cache.sizes
        let boundsAvailable = isHorizontal ? bounds.width : bounds.height
        let lines = cache.lines.isEmpty ? computeLines(sizes: sizes, available: min(boundsAvailable, maxPrimaryDimension)) : cache.lines

        var lineCrossExtents: [CGFloat] = []
        for line in lines {
            var maxCross: CGFloat = 0
            for idx in line {
                let size = sizes[idx]
                maxCross = max(maxCross, isHorizontal ? size.height : size.width)
            }
            lineCrossExtents.append(maxCross)
        }

        let orderedLines: [(lineItems: [Int], crossExtent: CGFloat)] = if reverseLines {
            zip(lines.reversed(), lineCrossExtents.reversed()).map { ($0.0, $0.1) }
        } else {
            zip(lines, lineCrossExtents).map { ($0.0, $0.1) }
        }

        var crossOffset: CGFloat = 0
        for (lineItems, crossExtent) in orderedLines {
            var primaryOffset: CGFloat = 0
            for idx in lineItems {
                let size = sizes[idx]
                let x: CGFloat
                let y: CGFloat
                if isHorizontal {
                    x = bounds.minX + primaryOffset
                    y = bounds.minY + crossOffset
                } else {
                    x = bounds.minX + crossOffset
                    y = bounds.minY + primaryOffset
                }
                subviews[idx].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                primaryOffset += (isHorizontal ? size.width : size.height) + spacing
            }
            crossOffset += crossExtent + spacing
        }
    }

    // MARK: - Private

    private func computeLines(sizes: [CGSize], available: CGFloat) -> [[Int]] {
        var lines: [[Int]] = []
        var currentLine: [Int] = []
        var currentPrimary: CGFloat = 0

        for (index, size) in sizes.enumerated() {
            let primary = isHorizontal ? size.width : size.height
            let needed = currentLine.isEmpty ? primary : primary + spacing

            let lineIsFull = currentLine.count >= maxItemsPerLine
            let exceedsBounds = !currentLine.isEmpty && (currentPrimary + needed > available) && available.isFinite

            if lineIsFull || exceedsBounds {
                lines.append(currentLine)
                currentLine = [index]
                currentPrimary = primary
            } else {
                currentLine.append(index)
                currentPrimary += needed
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines
    }

    private func totalSize(lines: [[Int]], sizes: [CGSize]) -> CGSize {
        guard !lines.isEmpty else { return .zero }

        var totalPrimary: CGFloat = 0
        var totalCross: CGFloat = 0

        for line in lines {
            var linePrimary: CGFloat = 0
            var lineCross: CGFloat = 0
            for (i, idx) in line.enumerated() {
                let size = sizes[idx]
                let primary = isHorizontal ? size.width : size.height
                let cross = isHorizontal ? size.height : size.width
                linePrimary += primary + (i > 0 ? spacing : 0)
                lineCross = max(lineCross, cross)
            }
            totalPrimary = max(totalPrimary, linePrimary)
            totalCross += lineCross
        }

        totalCross += spacing * CGFloat(lines.count - 1)

        if isHorizontal {
            return CGSize(width: totalPrimary, height: totalCross)
        } else {
            return CGSize(width: totalCross, height: totalPrimary)
        }
    }
}
