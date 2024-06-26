//
//  Misc Utils.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/13/24.
//

import Cocoa
import Defaults

func quitApp() {
    // Terminate the current application
    NSApplication.shared.terminate(nil)
}

func restartApplication ()-> Void {
    MessageUtil.showMessage(title: "Restart required.", message: "Please restart the application to apply your changes. Click OK to quit the app.", completion: { result in
        if result == .ok {
            quitApp()
        }})
}

func getWindowSize() -> CGSize {
    return CGSize(width: optimisticScreenSizeWidth / Defaults[.sizingMultiplier], height: optimisticScreenSizeHeight / Defaults[.sizingMultiplier])
}

// Helper extension to calculate distance between CGPoints
extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
}

// Measure string length in px
func measureString(_ string: String, fontSize: CGFloat, fontWeight: NSFont.Weight = .regular) -> CGSize {
    let font = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let attributedString = NSAttributedString(string: string, attributes: attributes)
    let size = attributedString.size()
    return size
}
