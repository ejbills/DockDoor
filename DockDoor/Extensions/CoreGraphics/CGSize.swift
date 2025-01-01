import Cocoa

extension CGSize {
    static func + (lhs: CGSize, rhs: CGSize) -> CGSize {
        CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
    }
}

extension CGSize {
    func scaleToFit(within maxSize: CGSize) -> CGSize {
        let widthRatio = maxSize.width / width
        let heightRatio = maxSize.height / height
        let scale = min(widthRatio, heightRatio)

        return CGSize(
            width: width * scale,
            height: height * scale
        )
    }
}
