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
extension Defaults.Keys {
    static let sizingMultiplier = Key<CGFloat>("sizingMultiplier") { 3 }
    static let windowPadding = Key<CGFloat>("windowPadding") { 0 }
    static let openDelay = Key<CGFloat>("openDelay") { 0 }
    static let showAnimations = Key<Bool>("showAnimations") { true }
    static let showWindowSwitcher = Key<Bool>("showWindowSwitcher"){ true }
    
    static let launched = Key<Bool>("launched") { false }
}
