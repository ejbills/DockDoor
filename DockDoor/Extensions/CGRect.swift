import Cocoa

extension CGRect {
    /// Extends the frame by the given value on all sides.
    /// - Parameter value: The amount to extend the frame.
    /// - Returns: A new `CGRect` extended by the specified value.
    func extended(by value: CGFloat) -> CGRect {
        CGRect(
            x: origin.x - value,
            y: origin.y - value,
            width: size.width + 2 * value,
            height: size.height + 2 * value
        )
    }
}
