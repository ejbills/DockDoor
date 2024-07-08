//
//  consts.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/6/24.
//

import Cocoa
import Defaults
//import Carbon

let optimisticScreenSizeWidth = NSScreen.main!.frame.width
let optimisticScreenSizeHeight = NSScreen.main!.frame.height

let roughHeightCap = optimisticScreenSizeHeight / 3
let roughWidthCap = optimisticScreenSizeWidth / 3
extension Defaults.Keys {
    static let sizingMultiplier = Key<CGFloat>("sizingMultiplier") { 3 }
    static let windowPadding = Key<CGFloat>("windowPadding") { 0 }
    static let openDelay = Key<CGFloat>("openDelay") { 0 }
    
    static let screenCaptureCacheLifespan = Key<CGFloat>("screenCaptureCacheLifespan") { 60 }
    static let uniformCardRadius = Key<Bool>("uniformCardRadius") { true }
    
    static let showAnimations = Key<Bool>("showAnimations") { true }
    static let enableWindowSwitcher = Key<Bool>("enableWindowSwitcher"){ true }
    static let showMenuBarIcon = Key<Bool>("showMenuBarIcon", default: true)
    static let defaultCMDTABKeybind = Key<Bool>("defaultCMDTABKeybind") { true }
    static let launched = Key<Bool>("launched") { false }
    static let Int64maskCommand = Key<Int>("Int64maskCommand") { 1048840 }
    static let Int64maskControl = Key<Int>("Int64maskControl") { 262401 }
    static let Int64maskAlternate = Key<Int>("Int64maskAlternate") { 524576 }
    static let UserKeybind = Key<UserKeyBind>("UserKeybind", default: UserKeyBind(keyCode: 48, modifierFlags: Defaults[.Int64maskControl]))
}
