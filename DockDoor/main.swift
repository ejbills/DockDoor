//
//  main.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/6/24.
//

import AppKit

let appDelegate = AppDelegate()

let application = NSApplication.shared
application.delegate = appDelegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
