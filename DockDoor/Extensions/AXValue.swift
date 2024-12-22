import Cocoa

extension AXValue {
    static func from(point: CGPoint) -> AXValue? {
        var point = point
        return AXValueCreate(.cgPoint, &point)
    }
}
