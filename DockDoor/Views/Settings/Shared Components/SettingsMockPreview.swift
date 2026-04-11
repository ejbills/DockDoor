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

    // MARK: - Dock appearance settings

    @Default(.trafficLightButtonsVisibility) private var dockTrafficLightVisibility
    @Default(.enabledTrafficLightButtons) private var dockEnabledTrafficLightButtons
    @Default(.useMonochromeTrafficLights) private var dockUseMonochrome
    @Default(.showWindowTitle) private var dockShowWindowTitle
    @Default(.windowTitleVisibility) private var dockWindowTitleVisibility
    @Default(.dockPreviewControlPosition) private var dockControlPosition
    @Default(.disableDockStyleTrafficLights) private var dockDisableStyleTrafficLights
    @Default(.disableDockStyleTitles) private var dockDisableStyleTitles
    @Default(.useEmbeddedDockPreviewElements) private var dockUseEmbedded
    @Default(.dockLivePreviewQuality) private var dockLivePreviewQuality
    @Default(.dockLivePreviewFrameRate) private var dockLivePreviewFrameRate

    // MARK: - Window Switcher appearance settings

    @Default(.switcherTrafficLightButtonsVisibility) private var switcherTrafficLightVisibility
    @Default(.switcherEnabledTrafficLightButtons) private var switcherEnabledTrafficLightButtons
    @Default(.switcherUseMonochromeTrafficLights) private var switcherUseMonochrome
    @Default(.switcherShowWindowTitle) private var switcherShowWindowTitle
    @Default(.switcherWindowTitleVisibility) private var switcherWindowTitleVisibility
    @Default(.windowSwitcherControlPosition) private var switcherControlPosition
    @Default(.switcherDisableDockStyleTrafficLights) private var switcherDisableStyleTrafficLights
    @Default(.windowSwitcherLivePreviewQuality) private var switcherLivePreviewQuality
    @Default(.windowSwitcherLivePreviewFrameRate) private var switcherLivePreviewFrameRate

    // MARK: - Cmd+Tab appearance settings

    @Default(.cmdTabTrafficLightButtonsVisibility) private var cmdTabTrafficLightVisibility
    @Default(.cmdTabEnabledTrafficLightButtons) private var cmdTabEnabledTrafficLightButtons
    @Default(.cmdTabUseMonochromeTrafficLights) private var cmdTabUseMonochrome
    @Default(.cmdTabShowWindowTitle) private var cmdTabShowWindowTitle
    @Default(.cmdTabWindowTitleVisibility) private var cmdTabWindowTitleVisibility
    @Default(.cmdTabControlPosition) private var cmdTabControlPosition
    @Default(.cmdTabDisableDockStyleTrafficLights) private var cmdTabDisableStyleTrafficLights
    @Default(.cmdTabDisableDockStyleTitles) private var cmdTabDisableStyleTitles
    @Default(.cmdTabUseEmbeddedDockPreviewElements) private var cmdTabUseEmbedded

    // MARK: - Shared appearance settings

    @Default(.showMinimizedHiddenLabels) private var showMinimizedHiddenLabels
    @Default(.selectionOpacity) private var selectionOpacity
    @Default(.unselectedContentOpacity) private var unselectedContentOpacity
    @Default(.hoverHighlightColor) private var hoverHighlightColor
    @Default(.allowDynamicImageSizing) private var allowDynamicImageSizing
    @Default(.hidePreviewCardBackground) private var hidePreviewCardBackground
    @Default(.tapEquivalentInterval) private var tapEquivalentInterval
    @Default(.previewHoverAction) private var previewHoverAction
    @Default(.showActiveWindowBorder) private var showActiveWindowBorder
    @Default(.activeAppIndicatorColor) private var activeAppIndicatorColor
    @Default(.showAnimations) private var showAnimations
    @Default(.globalPaddingMultiplier) private var globalPaddingMultiplier
    @Default(.windowTitleFontSize) private var windowTitleFontSize
    @Default(.trafficLightButtonScale) private var trafficLightButtonScale

    // MARK: - Header settings (used by container)

    @Default(.showAppName) private var showAppName
    @Default(.appNameStyle) private var appNameStyle
    @Default(.showAppIconOnly) private var showAppIconOnly
    @Default(.cmdTabShowAppName) private var cmdTabShowAppName
    @Default(.cmdTabAppNameStyle) private var cmdTabAppNameStyle
    @Default(.cmdTabShowAppIconOnly) private var cmdTabShowAppIconOnly
    @Default(.previewMaxRows) private var previewMaxRows
    @Default(.previewMaxColumns) private var previewMaxColumns
    @Default(.switcherMaxRows) private var switcherMaxRows

    init(context: SettingsMockPreviewContext) {
        self.context = context
        let windows = Self.generateMockWindows()
        _coordinator = StateObject(wrappedValue: Self.makeCoordinator(
            windows: windows,
            context: context
        ))
    }

    private var resolvedAppearance: PreviewAppearanceSettings {
        let isWindowSwitcher = context.windowSwitcherActive
        let isCmdTab = context == .cmdTab

        let trafficLightVisibility: TrafficLightButtonsVisibility = if isWindowSwitcher {
            switcherTrafficLightVisibility
        } else if isCmdTab {
            cmdTabTrafficLightVisibility
        } else {
            dockTrafficLightVisibility
        }

        let enabledButtons: Set<WindowAction> = if isWindowSwitcher {
            switcherEnabledTrafficLightButtons
        } else if isCmdTab {
            cmdTabEnabledTrafficLightButtons
        } else {
            dockEnabledTrafficLightButtons
        }

        let monochrome: Bool = if isWindowSwitcher {
            switcherUseMonochrome
        } else if isCmdTab {
            cmdTabUseMonochrome
        } else {
            dockUseMonochrome
        }

        let showTitle: Bool = if isWindowSwitcher {
            switcherShowWindowTitle
        } else if isCmdTab {
            cmdTabShowWindowTitle
        } else {
            dockShowWindowTitle
        }

        let titleVisibility: WindowTitleVisibility = if isWindowSwitcher {
            switcherWindowTitleVisibility
        } else if isCmdTab {
            cmdTabWindowTitleVisibility
        } else {
            dockWindowTitleVisibility
        }

        let controlPos: WindowSwitcherControlPosition = if isWindowSwitcher {
            switcherControlPosition
        } else if isCmdTab {
            cmdTabControlPosition
        } else {
            dockControlPosition
        }

        let disableStyleTrafficLights: Bool = if isWindowSwitcher {
            switcherDisableStyleTrafficLights
        } else if isCmdTab {
            cmdTabDisableStyleTrafficLights
        } else {
            dockDisableStyleTrafficLights
        }

        let disableStyleTitles: Bool = if isCmdTab {
            cmdTabDisableStyleTitles
        } else {
            dockDisableStyleTitles
        }

        let useEmbedded: Bool = if isCmdTab {
            cmdTabUseEmbedded
        } else {
            dockUseEmbedded
        }

        let quality = isWindowSwitcher ? switcherLivePreviewQuality : dockLivePreviewQuality
        let frameRate = isWindowSwitcher ? switcherLivePreviewFrameRate : dockLivePreviewFrameRate

        return PreviewAppearanceSettings(
            trafficLightVisibility: trafficLightVisibility,
            enabledTrafficLightButtons: enabledButtons,
            useMonochromeTrafficLights: monochrome,
            showWindowTitle: showTitle,
            windowTitleVisibility: titleVisibility,
            controlPosition: controlPos,
            useEmbeddedElements: useEmbedded,
            disableDockStyleTrafficLights: disableStyleTrafficLights,
            disableDockStyleTitles: disableStyleTitles,
            showMinimizedHiddenLabels: showMinimizedHiddenLabels,
            selectionOpacity: selectionOpacity,
            unselectedContentOpacity: unselectedContentOpacity,
            hoverHighlightColor: hoverHighlightColor,
            allowDynamicImageSizing: allowDynamicImageSizing,
            hidePreviewCardBackground: hidePreviewCardBackground,
            tapEquivalentInterval: tapEquivalentInterval,
            previewHoverAction: previewHoverAction,
            showActiveWindowBorder: showActiveWindowBorder,
            activeAppIndicatorColor: activeAppIndicatorColor,
            customSortGroupBorderColor: Defaults[.windowSwitcherCustomSortGroupBorderColor],
            showAnimations: showAnimations,
            globalPaddingMultiplier: globalPaddingMultiplier,
            windowTitleFontSize: windowTitleFontSize,
            trafficLightButtonScale: trafficLightButtonScale,
            livePreviewQuality: quality,
            livePreviewFrameRate: frameRate
        )
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
                hasScreenRecordingPermission: true,
                appearanceOverride: resolvedAppearance
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
