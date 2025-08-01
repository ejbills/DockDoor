import ApplicationServices
import Cocoa
import ScreenCaptureKit

enum OrphanedWindowUtil {
    /// Finds all windows that don't have proper bundle ID associations
    static func findOrphanedWindows() async -> [OrphanedWindowInfo] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            var orphanedWindows: [OrphanedWindowInfo] = []

            for window in content.windows {
                // Check if this window has issues with bundle ID association
                if let scApp = window.owningApplication {
                    // Try to find the corresponding NSRunningApplication
                    let nsApps = NSRunningApplication.runningApplications(withBundleIdentifier: scApp.bundleIdentifier)

                    // If no NSRunningApplication found with this bundle ID, it might be orphaned
                    if nsApps.isEmpty {
                        let orphanedInfo = OrphanedWindowInfo(
                            windowID: window.windowID,
                            windowTitle: window.title ?? "Untitled",
                            scAppBundleID: scApp.bundleIdentifier,
                            scAppPID: scApp.processID,
                            frame: window.frame,
                            windowLayer: window.windowLayer
                        )
                        orphanedWindows.append(orphanedInfo)
                    } else {
                        // Check if the window can be matched via accessibility
                        if let nsApp = nsApps.first {
                            let appElement = AXUIElementCreateApplication(nsApp.processIdentifier)
                            if let axWindows = try? appElement.windows(), !axWindows.isEmpty {
                                let matchedWindow = WindowUtil.findWindow(matchingWindow: window, in: axWindows)
                                if matchedWindow == nil {
                                    let orphanedInfo = OrphanedWindowInfo(
                                        windowID: window.windowID,
                                        windowTitle: window.title ?? "Untitled",
                                        scAppBundleID: scApp.bundleIdentifier,
                                        scAppPID: scApp.processID,
                                        frame: window.frame,
                                        windowLayer: window.windowLayer
                                    )
                                    orphanedWindows.append(orphanedInfo)
                                }
                            }
                        }
                    }
                } else {
                    // Window has no owning application at all
                    let orphanedInfo = OrphanedWindowInfo(
                        windowID: window.windowID,
                        windowTitle: window.title ?? "Untitled",
                        scAppBundleID: "unknown",
                        scAppPID: -1,
                        frame: window.frame,
                        windowLayer: window.windowLayer
                    )
                    orphanedWindows.append(orphanedInfo)
                }
            }

            return orphanedWindows

        } catch {
            return []
        }
    }

    /// Gets all running apps that could potentially be associated with orphaned windows
    static func getPotentialAssociationApps() -> [PotentialAssociationApp] {
        let runningApps = NSWorkspace.shared.runningApplications

        let potentialApps = runningApps.compactMap { app -> PotentialAssociationApp? in
            guard let bundleID = app.bundleIdentifier,
                  let name = app.localizedName,
                  app.activationPolicy == .regular
            else { return nil }

            return PotentialAssociationApp(
                bundleIdentifier: bundleID,
                processID: app.processIdentifier,
                localizedName: name,
                icon: app.icon ?? NSWorkspace.shared.icon(for: .applicationBundle)
            )
        }

        return potentialApps.sorted { $0.localizedName < $1.localizedName }
    }
}
