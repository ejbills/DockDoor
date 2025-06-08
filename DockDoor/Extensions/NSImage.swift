import Cocoa
import SwiftUI

extension NSImage.Name {
    static let logo = NSImage.Name("DDMiniIcon")
}

extension NSImage {
    func resizedToFit(in size: NSSize) -> NSImage {
        let newSize = if self.size.width > self.size.height {
            NSSize(width: size.width, height: size.width * self.size.height / self.size.width)
        } else {
            NSSize(width: size.height * self.size.width / self.size.height, height: size.height)
        }

        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()

        return resizedImage
    }

    func tint(color: NSColor) -> NSImage {
        let image = copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }

    func averageColor() -> Color? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // Create a 1x1 pixel context
        let width = 1
        let height = 1
        let bitsPerComponent = 8
        let bytesPerRow = 4 * width
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo)
        else {
            return nil
        }

        // Draw the image into the 1x1 context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Get the pixel data
        guard let data = context.data else {
            return nil
        }

        let pointer = data.bindMemory(to: UInt8.self, capacity: 4)
        let r = CGFloat(pointer[0]) / 255.0
        let g = CGFloat(pointer[1]) / 255.0
        let b = CGFloat(pointer[2]) / 255.0
        // let a = CGFloat(pointer[3]) / 255.0 // Alpha component, if needed

        return Color(red: r, green: g, blue: b)
    }
}
