import Cocoa

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
}
