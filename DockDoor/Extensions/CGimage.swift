import Cocoa

extension CGImage {
    func rotated(by degrees: CGFloat) -> CGImage? {
        let newWidth: Int
        let newHeight: Int
        var transform = CGAffineTransform.identity

        let radians = degrees * .pi / 180

        switch Int(degrees) % 360 {
        case 90, -270:
            newWidth = height
            newHeight = width
            transform = transform.translatedBy(x: CGFloat(newWidth), y: 0)
            transform = transform.rotated(by: radians)
        case 180, -180:
            newWidth = width
            newHeight = height
            transform = transform.translatedBy(x: CGFloat(newWidth), y: CGFloat(newHeight))
            transform = transform.rotated(by: radians)
        case 270, -90:
            newWidth = height
            newHeight = width
            transform = transform.translatedBy(x: 0, y: CGFloat(newHeight))
            transform = transform.rotated(by: radians)
        default: // 0 or 360
            return self // No rotation needed
        }

        guard let colorSpace,
              let context = CGContext(
                  data: nil,
                  width: newWidth,
                  height: newHeight,
                  bitsPerComponent: bitsPerComponent,
                  bytesPerRow: 0, // Automatically calculated
                  space: colorSpace,
                  bitmapInfo: bitmapInfo.rawValue
              )
        else {
            print("Failed to create CGContext for rotation.")
            return nil
        }

        context.concatenate(transform)
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }
}
