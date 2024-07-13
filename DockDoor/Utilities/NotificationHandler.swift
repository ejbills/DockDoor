//
//  NotificationHandler.swift
//  DockDoor
//
//  Created by Hasan Sultan on 7/13/24.
//

import Cocoa

extension AppClosureObserver {
    
    @objc func applicationDidTerminate(_ notification: Notification) 
    {
        self.handleWindowTableUpdate(notification, append: false)
    }
    
    @objc func applicationDidLaunch(_ notification: Notification)
    {
        self.handleWindowTableUpdate(notification, append: true)
    }
    
    func handleWindowTableUpdate(_ notification: Notification, append: Bool) {
        // Find by process ID and Applicatoin Name
        let applicationName = notification.userInfo!["NSApplicationName"] as! String
        let applicationPID = notification.userInfo!["NSApplicationProcessIdentifier"] as! pid_t
        if let (key, index) = WindowUtil.findKeyAndIndexBy_pid(pid: applicationPID ) {
            // Decision to delete or update
            if !append {
                WindowUtil.deleteWindowFromListUsingKeyIndex(key, index)
            } else {
                //print("launching", key, index)
                WindowUtil.updateWindowinListUsingKeyIndex(key, index)
            }
        }
        else {
            // First time finding this window, append it to the big list
            Task { [weak self] in
                do {
                    guard let self = self else {return}
                    _ = try await WindowUtil.activeWindows(for: applicationName)
                    await MainActor.run { [weak self] in
                        guard let self = self else {return}
                    }
                }
                catch {
                    print("Error: in WindowUtil.updateWindowTable")
                }
            }
        }
    }
}

extension WindowUtil {
    static func findKeyAndIndexBy_pid (pid: pid_t) -> (String, Int)? {
        for (key, windows) in WindowUtil.listOfAllWindowsInAllSpaces {
            if let index = windows.firstIndex(where: {$0.pid == pid}) {
                return (key, index)
            }
        }
        return nil
    }
}
