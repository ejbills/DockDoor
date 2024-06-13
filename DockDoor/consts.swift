//
//  consts.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/6/24.
//

import Cocoa
import Defaults

let optimisticScreenSizeWidth = NSScreen.main!.frame.width
let optimisticScreenSizeHeight = NSScreen.main!.frame.height

let roughHeightCap = optimisticScreenSizeHeight / 3
let roughWidthCap = optimisticScreenSizeWidth / 3

func getWindowSize(_ forScreen: NSScreen?) -> CGSize {    
    if let forScreen { return CGSize(width: forScreen.frame.width / Defaults[.sizingMultiplier], height: forScreen.frame.height / Defaults[.sizingMultiplier]) } else {
        return CGSize(width: roughWidthCap, height: roughHeightCap)
    }
}

extension Defaults.Keys {
    static let sizingMultiplier = Key<CGFloat>("sizingMultiplier") { 3 }
}
