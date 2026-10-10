import AppKit

struct SnapRegion: Hashable {
    let columns: Int
    let rows: Int
    let columnSpan: ClosedRange<Int>
    let rowSpan: ClosedRange<Int>
    let isInset: Bool

    init(columns: Int, rows: Int, columnSpan: ClosedRange<Int>, rowSpan: ClosedRange<Int>, isInset: Bool = false) {
        self.columns = max(columns, 1)
        self.rows = max(rows, 1)
        self.columnSpan = min(max(columnSpan.lowerBound, 0), self.columns - 1) ... min(max(columnSpan.upperBound, 0), self.columns - 1)
        self.rowSpan = min(max(rowSpan.lowerBound, 0), self.rows - 1) ... min(max(rowSpan.upperBound, 0), self.rows - 1)
        self.isInset = isInset
    }

    static let maximize = SnapRegion(columns: 1, rows: 1, columnSpan: 0 ... 0, rowSpan: 0 ... 0)
    static let almostMaximize = SnapRegion(columns: 1, rows: 1, columnSpan: 0 ... 0, rowSpan: 0 ... 0, isInset: true)
    static let leftHalf = SnapRegion(columns: 2, rows: 1, columnSpan: 0 ... 0, rowSpan: 0 ... 0)
    static let rightHalf = SnapRegion(columns: 2, rows: 1, columnSpan: 1 ... 1, rowSpan: 0 ... 0)
    static let topHalf = SnapRegion(columns: 1, rows: 2, columnSpan: 0 ... 0, rowSpan: 0 ... 0)
    static let bottomHalf = SnapRegion(columns: 1, rows: 2, columnSpan: 0 ... 0, rowSpan: 1 ... 1)
    static let topLeftQuarter = SnapRegion(columns: 2, rows: 2, columnSpan: 0 ... 0, rowSpan: 0 ... 0)
    static let topRightQuarter = SnapRegion(columns: 2, rows: 2, columnSpan: 1 ... 1, rowSpan: 0 ... 0)
    static let bottomLeftQuarter = SnapRegion(columns: 2, rows: 2, columnSpan: 0 ... 0, rowSpan: 1 ... 1)
    static let bottomRightQuarter = SnapRegion(columns: 2, rows: 2, columnSpan: 1 ... 1, rowSpan: 1 ... 1)

    static let almostMaximizeInsetFraction: CGFloat = 0.04

    var transposed: SnapRegion {
        SnapRegion(columns: rows, rows: columns, columnSpan: rowSpan, rowSpan: columnSpan, isInset: isInset)
    }

    var isMaximize: Bool {
        columns == 1 && rows == 1 && !isInset
    }

    func frame(in visibleFrame: CGRect, spacing: CGFloat = 0, includeEdges: Bool = true) -> CGRect {
        if isInset {
            let inset = min(visibleFrame.width, visibleFrame.height) * Self.almostMaximizeInsetFraction
            return Self.rounded(visibleFrame.insetBy(dx: inset, dy: inset))
        }

        let gap = max(spacing, 0)
        let edge = includeEdges ? gap : 0
        let area = visibleFrame.insetBy(dx: edge, dy: edge)

        let cellWidth = (area.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let cellHeight = (area.height - gap * CGFloat(rows - 1)) / CGFloat(rows)

        let columnCount = CGFloat(columnSpan.count)
        let rowCount = CGFloat(rowSpan.count)
        let width = cellWidth * columnCount + gap * (columnCount - 1)
        let height = cellHeight * rowCount + gap * (rowCount - 1)

        let x = area.minX + CGFloat(columnSpan.lowerBound) * (cellWidth + gap)
        let top = area.maxY - CGFloat(rowSpan.lowerBound) * (cellHeight + gap)

        return Self.rounded(CGRect(x: x, y: top - height, width: width, height: height))
    }

    private static func rounded(_ rect: CGRect) -> CGRect {
        let minX = rect.minX.rounded()
        let minY = rect.minY.rounded()
        return CGRect(x: minX, y: minY, width: rect.maxX.rounded() - minX, height: rect.maxY.rounded() - minY)
    }

    var localizedName: String {
        if isInset {
            return String(localized: "Almost Fill Screen", comment: "Snap region")
        }
        switch self {
        case .maximize: return String(localized: "Fill Screen", comment: "Snap region")
        case .leftHalf: return String(localized: "Left Half", comment: "Snap region")
        case .rightHalf: return String(localized: "Right Half", comment: "Snap region")
        case .topHalf: return String(localized: "Top Half", comment: "Snap region")
        case .bottomHalf: return String(localized: "Bottom Half", comment: "Snap region")
        case .topLeftQuarter: return String(localized: "Top Left", comment: "Snap region")
        case .topRightQuarter: return String(localized: "Top Right", comment: "Snap region")
        case .bottomLeftQuarter: return String(localized: "Bottom Left", comment: "Snap region")
        case .bottomRightQuarter: return String(localized: "Bottom Right", comment: "Snap region")
        default: break
        }

        if rows == 1, columns == 3 {
            switch (columnSpan.lowerBound, columnSpan.upperBound) {
            case (0, 0): return String(localized: "Left Third", comment: "Snap region")
            case (1, 1): return String(localized: "Middle Third", comment: "Snap region")
            case (2, 2): return String(localized: "Right Third", comment: "Snap region")
            case (0, 1): return String(localized: "Left Two Thirds", comment: "Snap region")
            case (1, 2): return String(localized: "Right Two Thirds", comment: "Snap region")
            default: break
            }
        }

        if columns == 1, rows == 3 {
            switch (rowSpan.lowerBound, rowSpan.upperBound) {
            case (0, 0): return String(localized: "Top Third", comment: "Snap region")
            case (1, 1): return String(localized: "Middle Third", comment: "Snap region")
            case (2, 2): return String(localized: "Bottom Third", comment: "Snap region")
            case (0, 1): return String(localized: "Top Two Thirds", comment: "Snap region")
            case (1, 2): return String(localized: "Bottom Two Thirds", comment: "Snap region")
            default: break
            }
        }

        let cells = columnSpan.count * rowSpan.count
        let total = columns * rows
        return String(localized: "Snap to \(cells)/\(total) of the Screen", comment: "Snap region with a fraction of the screen, e.g. 2/9")
    }
}

struct SnapScreenGeometry {
    let visibleFrame: CGRect
    let spacing: CGFloat
    let includeEdges: Bool

    func frame(for region: SnapRegion) -> CGRect {
        region.frame(in: visibleFrame, spacing: spacing, includeEdges: includeEdges)
    }

    static func usableFrame(visibleFrame: CGRect, stageManagerOffset: CGFloat, stageManagerOnLeft: Bool) -> CGRect {
        guard stageManagerOffset > 0, stageManagerOffset < visibleFrame.width / 2 else { return visibleFrame }
        var frame = visibleFrame
        frame.size.width -= stageManagerOffset
        if stageManagerOnLeft {
            frame.origin.x += stageManagerOffset
        }
        return frame
    }

    static func region(matching frame: CGRect, in visibleFrame: CGRect, spacing: CGFloat, includeEdges: Bool, candidates: [SnapRegion], tolerance: CGFloat = 4) -> SnapRegion? {
        candidates.first { candidate in
            let target = candidate.frame(in: visibleFrame, spacing: spacing, includeEdges: includeEdges)
            return abs(target.minX - frame.minX) <= tolerance && abs(target.minY - frame.minY) <= tolerance
                && abs(target.width - frame.width) <= tolerance && abs(target.height - frame.height) <= tolerance
        }
    }
}
