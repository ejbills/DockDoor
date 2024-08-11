import ApplicationServices
import Cocoa
import Defaults
import ScreenCaptureKit

final class WindowsUtil {
    let filteredBundleIdentifiers: [String] = ["com.apple.notificationcenterui"] // filters widgets

    /// Captures the image of a given window.
    static func getWindowImage(windowID: CGWindowID, bestResolution: Bool) -> CGImage? {
        CacheUtil.clearExpiredCache()

        if let cachedImage = CacheUtil.getCachedImage(for: windowID) {
            return cachedImage
        }

        let image = windowID.screenshot(bestResolution: true)
        guard let image = image else { return nil }

        CacheUtil.setCachedImage(for: windowID, image: image)

        return image
    }

    /// Retrieves the running application by its name.
    static func findRunningApplicationByName(named applicationName: String) -> NSRunningApplication? {
        return NSWorkspace.shared.runningApplications.first {
            applicationName.contains($0.localizedName ?? "") || ($0.localizedName?.contains(applicationName) ?? false)
        }
    }

    // Helper function to get the scale factor for a given window
    private static func getScaleFactorForWindow(windowID: CGWindowID) async -> CGFloat {
        return await MainActor.run {
            guard let window = NSApplication.shared.window(withWindowNumber: Int(windowID)) else {
                return NSScreen.main?.backingScaleFactor ?? 2.0
            }

            if NSScreen.screens.count > 1 {
                if let currentScreen = window.screen {
                    return currentScreen.backingScaleFactor
                }
            }

            return NSScreen.main?.backingScaleFactor ?? 2.0
        }
    }

    static func fetchWindowInfo(axWindow: AXUIElement, app: NSRunningApplication) -> Window? {
        if let wid = try? axWindow.cgWindowId(),
           let title = try? axWindow.title(),
           let subrole = try? axWindow.subrole(),
           let role = try? axWindow.role(),
           let size = try? axWindow.size(),
           let level = try? wid.level(),
           let isFullscreen = try? axWindow.isFullscreen(),
           let isMinimized = try? axWindow.isMinimized(),
           let closeButton = try? axWindow.closeButton()
        {
            if AXUIElement.isActualWindow(app, wid, level, title, subrole, role, size) {
                let image = getWindowImage(windowID: wid, bestResolution: true)
                return Window(
                    wid: wid,
                    app: app,
                    level: level,
                    title: title,
                    size: size,
                    appName: app.localizedName ?? "",
                    bundleID: app.bundleIdentifier,
                    image: image,
                    axElement: axWindow,
                    closeButton: closeButton,
                    isMinimized: isMinimized,
                    isFullscreen: isFullscreen
                )
            } else {
                print("It's not an actual window", axWindow)
            }
        } else {
            print("some error in fetchWindowInfo")
        }
        return nil
    }

    static func getRunningAppWindows(for app: NSRunningApplication) throws -> [Window] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        guard let windows = try appElement.windows() else {
            return []
        }
        return windows.compactMap { window in
            if let windowIntance = fetchWindowInfo(axWindow: window, app: app) {
                return windowIntance
            } else {
                return nil // probably not real window
            }
        }
    }
}

actor LimitedTaskGroup<T> {
    private var tasks: [Task<T, Error>] = []
    private let maxConcurrentTasks: Int
    private var runningTasks = 0
    private let semaphore: AsyncSemaphore

    init(maxConcurrentTasks: Int) {
        self.maxConcurrentTasks = maxConcurrentTasks
        semaphore = AsyncSemaphore(value: maxConcurrentTasks)
    }

    func addTask(_ operation: @escaping () async throws -> T) {
        let task = Task {
            await semaphore.wait()
            defer { Task { await semaphore.signal() } }
            return try await operation()
        }
        tasks.append(task)
    }

    func waitForAll() async throws -> [T] {
        defer { tasks.removeAll() }

        return try await withThrowingTaskGroup(of: T.self) { group in
            for task in tasks {
                group.addTask {
                    try await task.value
                }
            }

            var results: [T] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
}

actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        if value > 0 {
            value -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}
