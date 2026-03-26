import Defaults
import SwiftUI

enum SettingsMockPreviewContext {
    case dock
    case windowSwitcher
    case cmdTab

    var dockPosition: DockPosition {
        switch self {
        case .dock: .bottom
        case .windowSwitcher: .bottom
        case .cmdTab: .cmdTab
        }
    }

    var windowSwitcherActive: Bool {
        switch self {
        case .dock, .cmdTab: false
        case .windowSwitcher: true
        }
    }
}

struct SettingsMockPreview: View {
    let context: SettingsMockPreviewContext

    @StateObject private var coordinator: PreviewStateCoordinator

    init(context: SettingsMockPreviewContext) {
        self.context = context
        let windows = Self.generateMockWindows()
        _coordinator = StateObject(wrappedValue: Self.makeCoordinator(
            windows: windows,
            context: context
        ))
    }

    var body: some View {
        if !coordinator.windows.isEmpty {
            WindowPreviewHoverContainer(
                appName: "DockDoor (\u{2022}\u{203F}\u{2022})",
                onWindowTap: nil,
                dockPosition: context.dockPosition,
                mouseLocation: .zero,
                bestGuessMonitor: NSScreen.main!,
                dockItemElement: nil,
                windowSwitcherCoordinator: coordinator,
                mockPreviewActive: true,
                updateAvailable: false,
                hasScreenRecordingPermission: true
            )
            .allowsHitTesting(false)
        }
    }

    private static func generateMockWindows(count: Int = 2) -> [WindowInfo] {
        guard let baseNSImage = NSImage(named: "WindowsXP") else { return [] }

        let pid = NSRunningApplication.current.processIdentifier
        let dummyAXElement = unsafeBitCast(kCFNull, to: AXUIElement.self)
        let rotationAngles: [CGFloat] = [0, 90, 180, 270]
        let aspectRatios: [(CGFloat, CGFloat)] = [(300, 200), (200, 300), (400, 200), (180, 320)]

        var windows: [WindowInfo] = []
        for i in 0 ..< count {
            var image = baseNSImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            image = image?.rotated(by: rotationAngles[i % rotationAngles.count]) ?? image

            if image == nil {
                image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)?
                    .cgImage(forProposedRect: nil, context: nil, hints: nil)
            }

            let ratio = aspectRatios[i % aspectRatios.count]
            let provider = MockPreviewWindow(
                windowID: CGWindowID(i + 1),
                frame: CGRect(x: CGFloat(100 * (i + 1)), y: 100, width: ratio.0, height: ratio.1),
                title: "Window \(i + 1)",
                owningApplicationBundleIdentifier: "com.example.preview",
                owningApplicationProcessID: pid + pid_t(i + 1),
                isOnScreen: true,
                windowLayer: 0
            )
            windows.append(WindowInfo(
                windowProvider: provider,
                app: .current,
                image: image,
                axElement: dummyAXElement,
                appAxElement: dummyAXElement,
                closeButton: dummyAXElement,
                lastAccessedTime: Date(),
                isMinimized: false,
                isHidden: false
            ))
        }
        return windows
    }

    private static func makeCoordinator(windows: [WindowInfo], context: SettingsMockPreviewContext) -> PreviewStateCoordinator {
        let coordinator = PreviewStateCoordinator()
        coordinator.setWindows(
            windows,
            dockPosition: context.dockPosition,
            bestGuessMonitor: NSScreen.main!,
            isMockPreviewActive: true
        )
        coordinator.windowSwitcherActive = context.windowSwitcherActive
        if !windows.isEmpty {
            coordinator.setIndex(to: 0)
        }
        return coordinator
    }
}
