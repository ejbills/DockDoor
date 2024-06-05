//
//  DockDoorApp.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/3/24.
//

import SwiftUI

@main
struct DockDoorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
