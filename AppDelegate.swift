//
//  AppDelegate.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var dockObserver: DockObserver?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        dockObserver = DockObserver()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        if let observer = dockObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(
                observer,
                name: NSWorkspace.didActivateApplicationNotification,
                object: nil
            )
            print("DockObserver has stopped observing.")
        }
    }
}
