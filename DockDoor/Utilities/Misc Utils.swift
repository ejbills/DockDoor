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

func getWindowSize() -> CGSize {
    return CGSize(width: optimisticScreenSizeWidth / Defaults[.sizingMultiplier], height: optimisticScreenSizeHeight / Defaults[.sizingMultiplier])
}
