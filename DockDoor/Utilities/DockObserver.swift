import ApplicationServices
import Cocoa

struct ApplicationInfo: Sendable {
    let processIdentifier: pid_t
    let bundleIdentifier: String?
    let localizedName: String?

    func app() -> NSRunningApplication? {
        NSRunningApplication(processIdentifier: processIdentifier)
    }
}

struct ApplicationReturnType {
    enum Status {
        case success(NSRunningApplication)
        case notRunning(bundleIdentifier: String)
        case notFound
    }

    let status: Status
    let iconRect: CGRect?
}

func handleSelectedDockItemChangedNotification(observer _: AXObserver, element _: AXUIElement, notificationName _: CFString, _: UnsafeMutableRawPointer?) {
    DockObserver.shared.processSelectedDockItemChanged()
}

final class DockObserver {
    static let shared = DockObserver()

    var axObserver: AXObserver?
    var lastAppUnderMouse: ApplicationInfo?
    private var previousStatus: ApplicationReturnType.Status?
    private var hoverProcessingTask: Task<Void, Error>?
    private var isProcessing: Bool = false

    private init() {
        setupSelectedDockItemObserver()
    }

    private func hideWindowAndResetLastApp() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            lastAppUnderMouse = nil
            SharedPreviewWindowCoordinator.shared.hideWindow()
        }
    }

    private func setupSelectedDockItemObserver() {
        guard let dockAppPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier else {
            fatalError("Dock not found in running applications")
        }

        let dockAppElement = AXUIElementCreateApplication(dockAppPID)

        guard AXIsProcessTrusted() else {
            MessageUtil.showAlert(
                title: "Accessibility Permissions Required",
                message: "Please enable accessibility permissions in System Preferences > Security & Privacy > Privacy > Accessibility.",
                actions: [.ok]
            )
            return
        }

        guard let children = try? dockAppElement.children(), let axList = children.first(where: { element in
            try! element.role() == kAXListRole
        }) else {
            fatalError("Can't get dock items list element")
        }

        AXObserverCreate(dockAppPID, handleSelectedDockItemChangedNotification, &axObserver)
        guard let axObserver else { return }

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
            guard let self else { return }
            do {
                try Task.checkCancellation()
                guard !isProcessing,
                      await !SharedPreviewWindowCoordinator.shared.windowSwitcherCoordinator.windowSwitcherActive else { return }
                isProcessing = true
                defer {
                    self.isProcessing = false
                }

                let currentMouseLocation = DockObserver.getMousePosition()
                let appUnderMouseElement = getDockItemAppStatusUnderMouse()

                switch appUnderMouseElement.status {
                case let .success(currentAppUnderMouse):
                    guard let iconRect = appUnderMouseElement.iconRect else {
                        print("Icon rect is nil, cannot show window")
                        return
                    }

                    let currentAppInfo = ApplicationInfo(
                        processIdentifier: currentAppUnderMouse.processIdentifier,
                        bundleIdentifier: currentAppUnderMouse.bundleIdentifier,
                        localizedName: currentAppUnderMouse.localizedName
                    )

                    if currentAppInfo.processIdentifier != lastAppUnderMouse?.processIdentifier {
                        lastAppUnderMouse = currentAppInfo

                        Task { [weak self] in
                            guard let self else { return }
                            do {
                                guard let app = currentAppInfo.app() else {
                                    print("Failed to get NSRunningApplication for pid: \(currentAppInfo.processIdentifier)")
                                    return
                                }

                                let appWindows = try await WindowUtil.getActiveWindows(of: app)

                                await MainActor.run {
                                    if appWindows.isEmpty {
                                        self.hideWindowAndResetLastApp()
                                    } else {
                                        let mouseScreen = NSScreen.screenContainingMouse(currentMouseLocation)
                                        let convertedMouseLocation = DockObserver.nsPointFromCGPoint(currentMouseLocation, forScreen: mouseScreen)

                                        SharedPreviewWindowCoordinator.shared.showWindow(
                                            appName: currentAppInfo.localizedName ?? "Unknown",
                                            windows: appWindows,
                                            mouseLocation: convertedMouseLocation,
                                            mouseScreen: mouseScreen,
                                            iconRect: iconRect,
                                            onWindowTap: { [weak self] in
                                                self?.hideWindowAndResetLastApp()
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
                    previousStatus = .success(currentAppUnderMouse)

                case let .notRunning(bundleIdentifier):
                    if case .notRunning = previousStatus {
                        hideWindowAndResetLastApp()
                    }
                    previousStatus = .notRunning(bundleIdentifier: bundleIdentifier)

                case .notFound:
                    if await !SharedPreviewWindowCoordinator.shared.frame.contains(currentMouseLocation) {
                        hideWindowAndResetLastApp()
                    }
                    previousStatus = .notFound
                }
            } catch {
                print("Task cancelled or error occurred: \(error)")
            }
        }
    }

    func getHoveredApplicationDockItem() -> AXUIElement? {
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

        let subrole = try? hoveredDockItem.subrole()
        guard subrole == "AXApplicationDockItem" else {
            print("The hovered item is a \(subrole ?? "Unknown"), not AXApplicationDockItem")
            return nil
        }

        return hoveredDockItem
    }

    func getDockItemAppStatusUnderMouse() -> ApplicationReturnType {
        guard let hoveredDockItem = getHoveredApplicationDockItem() else {
            return ApplicationReturnType(status: .notFound, iconRect: nil)
        }

        let iconRect = getIconRect(for: hoveredDockItem)

        do {
            guard let appURL = try hoveredDockItem.attribute(kAXURLAttribute, NSURL.self)?.absoluteURL else {
                throw AxError.runtimeError
            }

            let bundle = Bundle(url: appURL)
            guard let bundleIdentifier = bundle?.bundleIdentifier else {
                print("App has no valid bundle. App URL: \(appURL.path)")

                // Fallback method
                guard let dockItemTitle = try hoveredDockItem.title() else {
                    print("Failed to get dock item title")
                    return ApplicationReturnType(status: .notFound, iconRect: iconRect)
                }

                if let app = WindowUtil.findRunningApplicationByName(named: dockItemTitle) {
                    return ApplicationReturnType(status: .success(app), iconRect: iconRect)
                } else {
                    print("Did not find app by name for dock item: \(dockItemTitle)")
                    return ApplicationReturnType(status: .notFound, iconRect: iconRect)
                }
            }

            if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                return ApplicationReturnType(status: .success(runningApp), iconRect: iconRect)
            } else {
                return ApplicationReturnType(status: .notRunning(bundleIdentifier: bundleIdentifier), iconRect: iconRect)
            }
        } catch {
            print("Error getting application status: \(error)")
            return ApplicationReturnType(status: .notFound, iconRect: iconRect)
        }
    }

    private func getIconRect(for dockItem: AXUIElement) -> CGRect? {
        do {
            guard let position = try dockItem.position(),
                  let size = try dockItem.size()
            else {
                return nil
            }
            return CGRect(origin: position, size: size)
        } catch {
            print("Error getting icon rect: \(error)")
            return nil
        }
    }

    static func getMousePosition() -> NSPoint {
        guard let event = CGEvent(source: nil) else {
            fatalError("Unable to get mouse event")
        }

        let mouseLocation = event.location

        let mousePosition = NSPoint(x: mouseLocation.x, y: mouseLocation.y)

        return mousePosition
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

    static func nsPointFromCGPoint(_ point: CGPoint, forScreen: NSScreen?) -> NSPoint {
        guard let screen = forScreen,
              let primaryScreen = NSScreen.screens.first
        else {
            return NSPoint(x: point.x, y: point.y)
        }

        let (_, offsetTop) = computeOffsets(for: screen, primaryScreen: primaryScreen)

        let y: CGFloat
        if screen == primaryScreen {
            y = screen.frame.size.height - point.y
        } else {
            let screenBottomOffset = primaryScreen.frame.size.height - (screen.frame.size.height + offsetTop)
            y = screen.frame.size.height + screenBottomOffset - (point.y - offsetTop)
        }

        return NSPoint(x: point.x, y: y)
    }

    static func cgPointFromNSPoint(_ point: CGPoint, forScreen: NSScreen?) -> CGPoint {
        guard let screen = forScreen,
              let primaryScreen = NSScreen.screens.first
        else {
            return CGPoint(x: point.x, y: point.y)
        }

        let (_, offsetTop) = computeOffsets(for: screen, primaryScreen: primaryScreen)
        let menuScreenHeight = screen.frame.maxY

        return CGPoint(x: point.x, y: menuScreenHeight - point.y + offsetTop)
    }
}
