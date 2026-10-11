import AppKit

struct SnapRegion: Hashable {
    let columns: Int
    let rows: Int
    let columnSpan: ClosedRange<Int>
    let rowSpan: ClosedRange<Int>

    init(columns: Int, rows: Int, columnSpan: ClosedRange<Int>, rowSpan: ClosedRange<Int>) {
        self.columns = max(columns, 1)
        self.rows = max(rows, 1)
        self.columnSpan = min(max(columnSpan.lowerBound, 0), self.columns - 1) ... min(max(columnSpan.upperBound, 0), self.columns - 1)
        self.rowSpan = min(max(rowSpan.lowerBound, 0), self.rows - 1) ... min(max(rowSpan.upperBound, 0), self.rows - 1)
    }

    static let maximize = SnapRegion(columns: 1, rows: 1, columnSpan: 0 ... 0, rowSpan: 0 ... 0)
    static let leftHalf = SnapRegion(columns: 2, rows: 1, columnSpan: 0 ... 0, rowSpan: 0 ... 0)
    static let rightHalf = SnapRegion(columns: 2, rows: 1, columnSpan: 1 ... 1, rowSpan: 0 ... 0)
    static let topLeftQuarter = SnapRegion(columns: 2, rows: 2, columnSpan: 0 ... 0, rowSpan: 0 ... 0)
    static let topRightQuarter = SnapRegion(columns: 2, rows: 2, columnSpan: 1 ... 1, rowSpan: 0 ... 0)
    static let bottomLeftQuarter = SnapRegion(columns: 2, rows: 2, columnSpan: 0 ... 0, rowSpan: 1 ... 1)
    static let bottomRightQuarter = SnapRegion(columns: 2, rows: 2, columnSpan: 1 ... 1, rowSpan: 1 ... 1)

    func frame(in visibleFrame: CGRect) -> CGRect {
        let cellWidth = visibleFrame.width / CGFloat(columns)
        let cellHeight = visibleFrame.height / CGFloat(rows)
        let width = cellWidth * CGFloat(columnSpan.count)
        let height = cellHeight * CGFloat(rowSpan.count)
        let x = visibleFrame.minX + CGFloat(columnSpan.lowerBound) * cellWidth
        let top = visibleFrame.maxY - CGFloat(rowSpan.lowerBound) * cellHeight

        let minX = x.rounded()
        let minY = (top - height).rounded()
        return CGRect(x: minX, y: minY, width: (x + width).rounded() - minX, height: top.rounded() - minY)
    }

    var localizedName: String {
        switch self {
        case .maximize: String(localized: "Fill Screen", comment: "Snap region")
        case .leftHalf: String(localized: "Left Half", comment: "Snap region")
        case .rightHalf: String(localized: "Right Half", comment: "Snap region")
        case .topLeftQuarter: String(localized: "Top Left", comment: "Snap region")
        case .topRightQuarter: String(localized: "Top Right", comment: "Snap region")
        case .bottomLeftQuarter: String(localized: "Bottom Left", comment: "Snap region")
        case .bottomRightQuarter: String(localized: "Bottom Right", comment: "Snap region")
        default: String(localized: "Snap", comment: "Snap region")
        }
    }
}

enum SnapScreenGeometry {
    static func usableFrame(visibleFrame: CGRect, stageManagerOffset: CGFloat, stageManagerOnLeft: Bool) -> CGRect {
        guard stageManagerOffset > 0, stageManagerOffset < visibleFrame.width / 2 else { return visibleFrame }
        var frame = visibleFrame
        frame.size.width -= stageManagerOffset
        if stageManagerOnLeft {
            frame.origin.x += stageManagerOffset
        }
        return frame
    }
}
