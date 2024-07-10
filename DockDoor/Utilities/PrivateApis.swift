//
//  PrivateApis.swift
//  DockDoor
//
//  Created by ShlomoCode on 10/07/2024.
//

import Cocoa

// returns the CGWindowID of the provided AXUIElement
// * macOS 10.10+
@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError
