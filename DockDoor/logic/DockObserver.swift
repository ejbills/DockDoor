import ApplicationServices
import Cocoa

func handleSelectedDockItemChangedNotification(observer _: AXObserver, element _: AXUIElement, notificationName _: CFString, _: UnsafeMutableRawPointer?) {
    DockObserver.shared.processSelectedDockItemChanged()
}

final class DockObserver {
    static let shared = DockObserver()

    var axObserver: AXObserver?
    var lastAppUnderMouse: NSRunningApplication?
    private var hoverProcessingTask: Task<Void, Error>?
    private var isProcessing: Bool = false

    private init() {
        setupSelectedDockItemObserver()
    }

    private func setupSelectedDockItemObserver() {
        guard let dockAppPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier else {
            fatalError("Dock does found in running applications")
        }

        let dockAppElement = AXUIElementCreateApplication(dockAppPID)

        guard let children = try? dockAppElement.children(), let axList = children.first(where: { element in
            try! element.role() == kAXListRole
        }) else {
            fatalError("can't get dock items list element")
        }

        AXObserverCreate(dockAppPID, handleSelectedDockItemChangedNotification, &axObserver)
        guard let axObserver = axObserver else { return }

        do {
            try axList.subscribeToNotification(axObserver, kAXSelectedChildrenChangedNotification) {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .commonModes)
            }
        } catch {
            fatalError("Failed to subscribe to notification: \(error)")
        }
    }

    func processSelectedDockItemChanged() {
        hoverProcessingTask?.cancel()
        hoverProcessingTask = Task { [weak self] in
            guard let self = self else { return }
            try Task.checkCancellation()
            guard !isProcessing, !ScreenCenteredFloatingWindow.shared.windowSwitcherActive else { return }
            isProcessing = true

            defer {
                isProcessing = false
            }

            if let currentAppUnderMouse = getCurrentAppUnderMouse() {
                if currentAppUnderMouse != lastAppUnderMouse {
                    lastAppUnderMouse = currentAppUnderMouse

                    Task { [weak self] in
                        guard let self = self else { return }
                        do {
                            let appWindows = try WindowsUtil.getRunningAppWindows(for: currentAppUnderMouse)
                            await MainActor.run {
                                if appWindows.isEmpty {
                                    SharedPreviewWindowCoordinator.shared.hidePreviewWindow()
                                } else {
                                    let mouseScreen = DockObserver.screenContainMouse(NSEvent.mouseLocation) ?? NSScreen.main!
                                    // Show HoverWindow (using shared instance)
                                    SharedPreviewWindowCoordinator.shared.showPreviewWindow(
                                        appName: currentAppUnderMouse.localizedName!,
                                        windows: appWindows,
                                        mouseLocation: NSEvent.mouseLocation,
                                        mouseScreen: mouseScreen,
                                        onWindowTap: { [weak self] in
                                            SharedPreviewWindowCoordinator.shared.hidePreviewWindow()
                                            self?.lastAppUnderMouse = nil
                                        }
                                    )
                                }
                            }
                        } catch {
                            await MainActor.run {
                                print("Error fetching active windows: \(error)")
                            }
                        }
                    }
                }
            } else {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    let mouseScreen = DockObserver.screenContainMouse(NSEvent.mouseLocation) ?? NSScreen.main!
                    if !SharedPreviewWindowCoordinator.shared.frame.contains(NSEvent.mouseLocation) {
                        self.lastAppUnderMouse = nil
                        SharedPreviewWindowCoordinator.shared.hidePreviewWindow()
                    }
                }
            }
        }
    }

    func getDockIconFrameAtLocation(_ mouseLocation: CGPoint) -> CGRect? {
        guard let hoveredDockItem = gethoveredDockItem() else {
            print("No selected dock item found")
            return nil
        }

        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        let positionResult = AXUIElementCopyAttributeValue(hoveredDockItem, kAXPositionAttribute as CFString, &positionValue)
        let sizeResult = AXUIElementCopyAttributeValue(hoveredDockItem, kAXSizeAttribute as CFString, &sizeValue)

        guard positionResult == .success, sizeResult == .success else {
            print("Failed to get position or size for selected dock item")
            return nil
        }

        let position = positionValue as! AXValue
        let size = sizeValue as! AXValue
        var positionPoint = CGPoint.zero
        var sizeCGSize = CGSize.zero
        AXValueGetValue(position, .cgPoint, &positionPoint)
        AXValueGetValue(size, .cgSize, &sizeCGSize)

        let iconRect = CGRect(origin: positionPoint, size: sizeCGSize)

        // Adjust mouse location to match the coordinate system of the dock icons
        let adjustedMouseLocation = CGPoint(
            x: mouseLocation.x,
            y: (DockObserver.screenContainMouse(mouseLocation)?.frame.height ?? NSScreen.main!.frame.height) - mouseLocation.y
        )

        print("Checking icon rect: \(iconRect) with adjusted mouse location: \(adjustedMouseLocation)")

        if iconRect.contains(adjustedMouseLocation) {
            print("Matched icon rect: \(iconRect)")
            return iconRect
        }

        print("No matching icon rect found")
        return nil
    }

    func gethoveredDockItem() -> AXUIElement? {
        guard let dockAppPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier else {
            print("Dock does found in running applications")
            return nil
        }

        let dockAppElement = AXUIElementCreateApplication(dockAppPID)

        var dockItems: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockAppElement, kAXChildrenAttribute as CFString, &dockItems) == .success, let dockItems = dockItems as? [AXUIElement], !dockItems.isEmpty else {
            print("Failed to get dock items or no dock items found")
            return nil
        }

        var hoveredDockItem: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockItems.first!, kAXSelectedChildrenAttribute as CFString, &hoveredDockItem) == .success, !dockItems.isEmpty, let hoveredDockItem = (hoveredDockItem as! [AXUIElement]).first else {
            // no app under nouse
            return nil
        }

        return hoveredDockItem
    }

    func getCurrentAppUnderMouse() -> NSRunningApplication? {
        guard let hoveredDockItem = gethoveredDockItem() else {
            return nil
        }

        var appURL: CFTypeRef?
        guard AXUIElementCopyAttributeValue(hoveredDockItem, kAXURLAttribute as CFString, &appURL) == .success, let appURL = appURL as? NSURL as? URL else {
            print("Failed to get app URL or convert NSURL to URL")
            return nil
        }

        let budle = Bundle(url: appURL)
        guard let bundleIdentifier = budle?.bundleIdentifier else {
            print("App has no valid bundle. app url: \(appURL)") // For example: scrcpy, Android studio emulator

            var dockItemTitle: CFTypeRef?
            guard AXUIElementCopyAttributeValue(hoveredDockItem, kAXTitleAttribute as CFString, &dockItemTitle) == .success, let dockItemTitle = dockItemTitle as? String else {
                print("Failed to get dock item title")
                return nil
            }

            if let app = WindowsUtil.findRunningApplicationByName(named: dockItemTitle) {
                return app
            } else {
                return nil
            }
        }

        guard let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            print("Current App is not running (\(bundleIdentifier))")
            return nil
        }

        print("Current App is running (\(runningApp))")
        return runningApp
    }

    static func screenContainMouse(_ point: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        guard let primaryScreen = screens.first else { return nil }

        for screen in screens {
            let (offsetLeft, offsetTop) = computeOffsets(for: screen, primaryScreen: primaryScreen)

            if point.x >= offsetLeft, point.x <= offsetLeft + screen.frame.size.width,
               point.y >= offsetTop, point.y <= offsetTop + screen.frame.size.height
            {
                return screen
            }
        }

        return primaryScreen
    }

    private static func computeOffsets(for screen: NSScreen, primaryScreen: NSScreen) -> (CGFloat, CGFloat) {
        var offsetLeft = screen.frame.origin.x
        var offsetTop = primaryScreen.frame.size.height - (screen.frame.origin.y + screen.frame.size.height)

        if screen == primaryScreen {
            offsetTop = 0
            offsetLeft = 0
        }

        return (offsetLeft, offsetTop)
    }
}
