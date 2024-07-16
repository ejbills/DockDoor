//
//  WindowClosureObservers.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/30/24.
//

import Foundation
import AppKit

class AppClosureObserver {
    static let shared = AppClosureObserver()

    private init() {
        setupObservers()
    }
        
    private func setupObservers() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(self, selector: #selector(appDidTerminate(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appDidActivate(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }
    
    @objc private func appDidTerminate(_ notification: Notification) {
        SharedPreviewWindowCoordinator.shared.hidePreviewWindow()
    }
    
    @objc private func appDidActivate(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // add a delay to prevent interference with button clicks, which hide the window on their own
            if SharedPreviewWindowCoordinator.shared.isVisible {
                SharedPreviewWindowCoordinator.shared.hidePreviewWindow()
            }
        }
    }
}
