import Defaults
import SwiftUI

enum PreviewContext: String, CaseIterable, Identifiable {
    case dock, windowSwitcher, cmdTab
    var id: String { rawValue }
    var displayName: LocalizedStringKey {
        switch self {
        case .dock: "Dock Previews"
        case .windowSwitcher: "Window Switcher"
        case .cmdTab: "Cmd+Tab"
        }
    }
}

// MARK: - Mock Data Generation

extension AppearanceSettingsView {
    private static func generateMockWindowsForPreview(count: Int = 2) -> [WindowInfo] {
        guard let baseNSImage = NSImage(named: "WindowsXP") else {
            return []
        }

        let pid = NSRunningApplication.current.processIdentifier
        var mockWindows: [WindowInfo] = []
        let geometricRotationAngles: [CGFloat] = [0, 90, 180, 270] // Degrees

        for i in 0 ..< count {
            let mockNsApp = NSRunningApplication.current
            let dummyAXElement = unsafeBitCast(kCFNull, to: AXUIElement.self)

            var processedImage: CGImage? = baseNSImage.cgImage(forProposedRect: nil, context: nil, hints: nil)

            let angleIndex = i % geometricRotationAngles.count
            let deterministicGeometricAngle = geometricRotationAngles[angleIndex] // Degrees
            processedImage = processedImage?.rotated(by: deterministicGeometricAngle) ?? processedImage

            if processedImage == nil {
                processedImage = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error processing image")?
                    .cgImage(forProposedRect: nil, context: nil, hints: nil)
            }

            let aspectRatios: [(width: CGFloat, height: CGFloat)] = [
                (300, 200), // 3:2 landscape
                (200, 300), // 2:3 portrait
                (400, 200), // 2:1 wide landscape
                (180, 320), // 9:16 tall portrait
            ]
            let aspectRatio = aspectRatios[i % aspectRatios.count]

            let mockWindowProvider = MockPreviewWindow(
                windowID: CGWindowID(i + 1),
                frame: CGRect(x: CGFloat(100 * (i + 1)), y: 100, width: aspectRatio.width, height: aspectRatio.height),
                title: "Window \(i + 1)",
                owningApplicationBundleIdentifier: "com.example.preview",
                owningApplicationProcessID: pid + pid_t(i + 1),
                isOnScreen: true,
                windowLayer: 0
            )
            mockWindows.append(
                WindowInfo(
                    windowProvider: mockWindowProvider,
                    app: mockNsApp,
                    image: processedImage,
                    axElement: dummyAXElement,
                    appAxElement: dummyAXElement,
                    closeButton: dummyAXElement,
                    lastAccessedTime: Date(),
                    isMinimized: false,
                    isHidden: false
                )
            )
        }
        return mockWindows
    }

    static func getMockCoordinator(windows: [WindowInfo], windowSwitcherActive: Bool, dockPosition: DockPosition, bestGuessMonitor: NSScreen) -> PreviewStateCoordinator {
        let coordinator = PreviewStateCoordinator()
        coordinator.setWindows(windows, dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: true)
        coordinator.windowSwitcherActive = windowSwitcherActive
        if !windows.isEmpty {
            coordinator.setIndex(to: 0)
        }
        return coordinator
    }
}

struct AppearanceSettingsView: View {
    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.allowDynamicImageSizing) var allowDynamicImageSizing
    @Default(.useLiquidGlass) var useLiquidGlass
    @Default(.showAppName) var showAppName
    @Default(.appNameStyle) var appNameStyle
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleVisibility) var windowTitleVisibility
    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.windowSwitcherControlPosition) var windowSwitcherControlPosition
    @Default(.dockPreviewControlPosition) var dockPreviewControlPosition

    @Default(.selectionOpacity) var selectionOpacity
    @Default(.unselectedContentOpacity) var unselectedContentOpacity
    @Default(.hoverHighlightColor) var hoverHighlightColor
    @Default(.dockPreviewBackgroundOpacity) var dockPreviewBackgroundOpacity
    @Default(.hidePreviewCardBackground) var hidePreviewCardBackground
    @Default(.hideHoverContainerBackground) var hideHoverContainerBackground
    @Default(.showActiveWindowBorder) var showActiveWindowBorder
    @Default(.previewMaxColumns) var previewMaxColumns
    @Default(.previewMaxRows) var previewMaxRows
    @Default(.switcherMaxRows) var switcherMaxRows
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.globalPaddingMultiplier) var globalPaddingMultiplier
    @Default(.useEmbeddedDockPreviewElements) var useEmbeddedDockPreviewElements
    @Default(.disableDockStyleTrafficLights) var disableDockStyleTrafficLights
    @Default(.disableDockStyleTitles) var disableDockStyleTitles
    @Default(.showMinimizedHiddenLabels) var showMinimizedHiddenLabels
    @Default(.enableTitleMarquee) var enableTitleMarquee

    // MARK: - Window Switcher Appearance Settings

    @Default(.switcherShowWindowTitle) var switcherShowWindowTitle
    @Default(.switcherWindowTitleVisibility) var switcherWindowTitleVisibility
    @Default(.switcherTrafficLightButtonsVisibility) var switcherTrafficLightButtonsVisibility
    @Default(.switcherEnabledTrafficLightButtons) var switcherEnabledTrafficLightButtons
    @Default(.switcherUseMonochromeTrafficLights) var switcherUseMonochromeTrafficLights
    @Default(.switcherDisableDockStyleTrafficLights) var switcherDisableDockStyleTrafficLights

    // MARK: - Cmd+Tab Appearance Settings

    @Default(.cmdTabShowAppName) var cmdTabShowAppName
    @Default(.cmdTabAppNameStyle) var cmdTabAppNameStyle
    @Default(.cmdTabShowAppIconOnly) var cmdTabShowAppIconOnly
    @Default(.cmdTabShowWindowTitle) var cmdTabShowWindowTitle
    @Default(.cmdTabWindowTitleVisibility) var cmdTabWindowTitleVisibility
    @Default(.cmdTabWindowTitlePosition) var cmdTabWindowTitlePosition
    @Default(.cmdTabTrafficLightButtonsVisibility) var cmdTabTrafficLightButtonsVisibility
    @Default(.cmdTabTrafficLightButtonsPosition) var cmdTabTrafficLightButtonsPosition
    @Default(.cmdTabEnabledTrafficLightButtons) var cmdTabEnabledTrafficLightButtons
    @Default(.cmdTabUseMonochromeTrafficLights) var cmdTabUseMonochromeTrafficLights
    @Default(.cmdTabControlPosition) var cmdTabControlPosition
    @Default(.cmdTabUseEmbeddedDockPreviewElements) var cmdTabUseEmbeddedDockPreviewElements
    @Default(.cmdTabDisableDockStyleTrafficLights) var cmdTabDisableDockStyleTrafficLights
    @Default(.cmdTabDisableDockStyleTitles) var cmdTabDisableDockStyleTitles

    // Compact mode settings
    @Default(.compactModeTitleFormat) var compactModeTitleFormat
    @Default(.compactModeItemSize) var compactModeItemSize
    @Default(.windowSwitcherCompactThreshold) var windowSwitcherCompactThreshold
    @Default(.dockPreviewCompactThreshold) var dockPreviewCompactThreshold
    @Default(.cmdTabCompactThreshold) var cmdTabCompactThreshold

    // Force compact mode settings
    @Default(.disableImagePreview) var disableImagePreview
    @StateObject private var permissionsChecker = PermissionsChecker()

    private var isCompactModeForced: Bool {
        disableImagePreview || !permissionsChecker.screenRecordingPermission
    }

    @State private var showAdvancedAppearanceSettings: Bool = false
    @State private var selectedPreviewContext: PreviewContext = .dock

    @State private var previousWindowTitlePosition: WindowTitlePosition
    @State private var mockAppNameForPreview: String = "DockDoor (•‿•)"
    @StateObject private var mockWindowSwitcherCoordinator: PreviewStateCoordinator
    @StateObject private var mockDockPreviewCoordinator: PreviewStateCoordinator

    private let advancedAppearanceSettingsSectionID = "advancedAppearanceSettingsSection"

    init() {
        _previousWindowTitlePosition = State(initialValue: Defaults[.windowTitlePosition])

        let initialMockWindows = AppearanceSettingsView.generateMockWindowsForPreview()

        _mockDockPreviewCoordinator = StateObject(wrappedValue: AppearanceSettingsView.getMockCoordinator(
            windows: initialMockWindows,
            windowSwitcherActive: false,
            dockPosition: .bottom,
            bestGuessMonitor: NSScreen.main!
        ))
        _mockWindowSwitcherCoordinator = StateObject(wrappedValue: AppearanceSettingsView.getMockCoordinator(
            windows: initialMockWindows,
            windowSwitcherActive: true,
            dockPosition: .bottom,
            bestGuessMonitor: NSScreen.main!
        ))
    }

    var body: some View {
        ScrollViewReader { proxy in
            BaseSettingsView {
                VStack(alignment: .leading, spacing: 16) {
                    if !permissionsChecker.screenRecordingPermission {
                        CompactModeWarningBanner(
                            hasScreenRecordingPermission: permissionsChecker.screenRecordingPermission,
                            disableImagePreview: disableImagePreview
                        )
                    }

                    StyledGroupBox(label: "Window Preview Size") {
                        VStack(alignment: .leading, spacing: 10) {
                            WindowSizeSliderView()

                            Text("Choose how large window previews appear when hovering over dock icons. All window images are automatically scaled to fit within this size while maintaining their original proportions.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading) {
                            Toggle(isOn: $allowDynamicImageSizing) {
                                Text("Allow dynamic image sizing")
                            }
                            .onChange(of: allowDynamicImageSizing) { _ in
                                // Recalculate dimensions for both mock coordinators when dynamic sizing changes
                                let dockPosition = DockPosition.bottom
                                let monitor = NSScreen.main!
                                mockDockPreviewCoordinator.recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: monitor, isMockPreviewActive: true)
                                mockWindowSwitcherCoordinator.recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: monitor, isMockPreviewActive: true)
                            }
                            Text("Allows window preview images to scale dynamically to reasonable dimensions, overriding fixed frame constraints.")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .padding(.leading, 20)
                        }
                    }

                    StyledGroupBox(label: "General Appearance") {
                        VStack(alignment: .leading, spacing: 10) {
                            if #available(macOS 26.0, *) {
                                Toggle(isOn: $useLiquidGlass) {
                                    Text("Use Liquid Glass (macOS 26+)")
                                }
                            }
                            sliderSetting(title: "Spacing Scale",
                                          value: $globalPaddingMultiplier,
                                          range: 0.5 ... 2.0,
                                          step: 0.1,
                                          unit: "×",
                                          formatter: {
                                              let f = NumberFormatter()
                                              f.minimumFractionDigits = 1
                                              f.maximumFractionDigits = 1
                                              return f
                                          }())

                            sliderSetting(title: "Unselected Content Opacity",
                                          value: $unselectedContentOpacity,
                                          range: 0 ... 1,
                                          step: 0.05,
                                          unit: "",
                                          formatter: NumberFormatter.percentFormatter)

                            VStack(alignment: .leading) {
                                Toggle(isOn: $uniformCardRadius) {
                                    Text("Rounded corners")
                                }
                                Text("Round the corners of window preview images for a modern look.")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 20)
                            }

                            VStack(alignment: .leading) {
                                Toggle(isOn: $enableTitleMarquee) {
                                    Text("Scroll long titles (marquee)")
                                }
                                Text("When disabled, long titles remain static instead of scrolling.")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 20)
                            }

                            VStack(alignment: .leading) {
                                Toggle(isOn: $showMinimizedHiddenLabels) {
                                    Text("Distinguish minimized/hidden windows")
                                }
                                Text("When enabled, shows visual indicators and dims minimized/hidden windows. When disabled, treats them as normal windows with full functionality.")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 20)
                            }

                            VStack(alignment: .leading) {
                                Toggle(isOn: $hidePreviewCardBackground) {
                                    Text("Hide preview card background")
                                }
                                Text("Removes the background panel from individual window previews.")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 20)
                            }

                            VStack(alignment: .leading) {
                                Toggle(isOn: $hideHoverContainerBackground) {
                                    Text("Hide hover container background")
                                }
                                Text("Removes the root background blur from the hover container.")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 20)
                            }

                            VStack(alignment: .leading) {
                                Toggle(isOn: $showActiveWindowBorder) {
                                    Text("Show active window border")
                                }
                                Text("Highlights the currently focused window with a colored border.")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 20)
                            }
                        }
                    }

                    StyledGroupBox(label: "Compact Mode (Titles Only)") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Compact mode displays windows as a streamlined vertical list with app icons and titles.")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Toggle(isOn: Binding(
                                    get: { !permissionsChecker.screenRecordingPermission || disableImagePreview },
                                    set: { disableImagePreview = $0 }
                                )) {
                                    Text("Always use compact mode")
                                }
                                .disabled(!permissionsChecker.screenRecordingPermission)

                                if !permissionsChecker.screenRecordingPermission {
                                    HStack(spacing: 4) {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                        Text("Screen Recording permission is required for window thumbnails.")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.orange)
                                    .padding(.leading, 20)
                                }
                            }

                            if !isCompactModeForced {
                                Divider().padding(.vertical, 2)
                                Text("Window Threshold").font(.headline).padding(.bottom, -2)

                                Text("Set a threshold to automatically switch to compact mode when an app has that many or more windows. Set to 0 to disable.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                compactThresholdSlider(
                                    title: "Window Switcher",
                                    value: $windowSwitcherCompactThreshold,
                                    description: "Switch to compact list in window switcher when window count reaches threshold."
                                )

                                compactThresholdSlider(
                                    title: "Dock Previews",
                                    value: $dockPreviewCompactThreshold,
                                    description: "Switch to compact list in dock previews when window count reaches threshold."
                                )

                                compactThresholdSlider(
                                    title: "Cmd+Tab Enhancement",
                                    value: $cmdTabCompactThreshold,
                                    description: "Switch to compact list in Cmd+Tab overlay when window count reaches threshold."
                                )
                            }

                            Divider().padding(.vertical, 2)
                            Text("Appearance").font(.headline).padding(.bottom, -2)

                            Picker("Item Size", selection: $compactModeItemSize) {
                                ForEach(CompactModeItemSize.allCases) { size in
                                    Text(size.localizedName).tag(size)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Title Format", selection: $compactModeTitleFormat) {
                                ForEach(CompactModeTitleFormat.allCases) { format in
                                    Text(format.localizedName).tag(format)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    VStack {
                        Picker("", selection: $selectedPreviewContext.animation(Animation.smooth)) {
                            ForEach(PreviewContext.allCases) { context in
                                Text(context.displayName).tag(context)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack {
                        let currentCoordinator: PreviewStateCoordinator = switch selectedPreviewContext {
                        case .dock, .cmdTab:
                            mockDockPreviewCoordinator
                        case .windowSwitcher:
                            mockWindowSwitcherCoordinator
                        }
                        let currentDockPosition: DockPosition = switch selectedPreviewContext {
                        case .dock:
                            .bottom
                        case .windowSwitcher:
                            .bottom
                        case .cmdTab:
                            .cmdTab
                        }
                        if !currentCoordinator.windows.isEmpty {
                            WindowPreviewHoverContainer(
                                appName: mockAppNameForPreview,
                                onWindowTap: nil,
                                dockPosition: currentDockPosition,
                                mouseLocation: .zero,
                                bestGuessMonitor: NSScreen.main!,
                                dockItemElement: nil,
                                windowSwitcherCoordinator: currentCoordinator,
                                mockPreviewActive: true,
                                updateAvailable: false,
                                hasScreenRecordingPermission: true
                            )
                            .allowsHitTesting(false)
                        } else {
                            Text("Loading preview...")
                                .frame(minHeight: 150, maxHeight: 250)
                        }
                    }

                    StyledGroupBox(label: contextSettingsLabel) {
                        VStack(alignment: .leading, spacing: 10) {
                            switch selectedPreviewContext {
                            case .dock:
                                dockPreviewSettings
                            case .windowSwitcher:
                                windowSwitcherPreviewSettings
                            case .cmdTab:
                                cmdTabPreviewSettings
                            }
                        }
                    }

                    advancedSettingsToggle(proxy: proxy)

                    if showAdvancedAppearanceSettings {
                        advancedAppearanceSettingsSection
                            .id(advancedAppearanceSettingsSectionID)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dockPreviewSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            // App Header section
            Toggle(isOn: $showAppName) {
                Text("Show App Header")
            }

            if showAppName {
                Picker(String(localized: "App Header Style"), selection: $appNameStyle) {
                    ForEach(AppNameStyle.allCases, id: \.self) { style in
                        Text(style.localizedName)
                            .tag(style)
                    }
                }

                Toggle(isOn: $showAppIconOnly) {
                    Text("Show App Icon Only")
                }
            }

            Divider().padding(.vertical, 2)
            Text("Dock Preview Toolbar").font(.headline).padding(.bottom, -2)

            Picker("Position Dock Preview Controls", selection: $dockPreviewControlPosition) {
                ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Toggle(isOn: $showWindowTitle) {
                Text("Show Window Title")
            }

            if showWindowTitle {
                Picker("Window Title Visibility", selection: $windowTitleVisibility) {
                    ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                        Text(visibility.localizedName)
                            .tag(visibility)
                    }
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $disableDockStyleTitles) {
                        Text("Disable dock styling on window titles")
                    }
                    Text("Removes the pill-shaped background styling from window titles in dock previews for a cleaner look.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }
            }

            Divider().padding(.vertical, 2)
            Text("Traffic Light Buttons in Previews").font(.headline).padding(.bottom, -2)
            TrafficLightButtonsSettingsView()

            VStack(alignment: .leading) {
                Toggle(isOn: $disableDockStyleTrafficLights) {
                    Text("Disable dock styling on traffic light buttons")
                }
                Text("Removes the pill-shaped background styling from traffic light buttons in dock previews for a cleaner look.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }

            Divider().padding(.vertical, 2)
            Text("Dock Preview Layout").font(.headline).padding(.bottom, -2)

            VStack(alignment: .leading) {
                Toggle(isOn: $useEmbeddedDockPreviewElements) {
                    Text("Embed controls in preview frames")
                }
                Text("Places traffic light buttons and window titles directly inside the dock preview frames for a more compact and minimal appearance.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }

            VStack(alignment: .leading, spacing: 4) {
                let previewMaxRowsBinding = Binding<Double>(
                    get: { Double(previewMaxRows) },
                    set: { previewMaxRows = Int($0) }
                )
                sliderSetting(title: "Max Rows (Bottom Dock)",
                              value: previewMaxRowsBinding,
                              range: 1.0 ... 8.0,
                              step: 1.0,
                              unit: "",
                              formatter: {
                                  let f = NumberFormatter()
                                  f.minimumFractionDigits = 0
                                  f.maximumFractionDigits = 0
                                  return f
                              }())

                let previewMaxColumnsBinding = Binding<Double>(
                    get: { Double(previewMaxColumns) },
                    set: { previewMaxColumns = Int($0) }
                )
                sliderSetting(title: "Max Columns (Left/Right Dock)",
                              value: previewMaxColumnsBinding,
                              range: 1.0 ... 8.0,
                              step: 1.0,
                              unit: "",
                              formatter: {
                                  let f = NumberFormatter()
                                  f.minimumFractionDigits = 0
                                  f.maximumFractionDigits = 0
                                  return f
                              }())

                Text(String(localized: "Controls how many rows/columns of windows are shown in dock previews. Only the relevant setting applies based on dock position."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var windowSwitcherPreviewSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Position Window Controls", selection: $windowSwitcherControlPosition) {
                ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Divider().padding(.vertical, 2)
            Text("Traffic Light Buttons").font(.headline).padding(.bottom, -2)

            Picker("Visibility", selection: $switcherTrafficLightButtonsVisibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility)
                }
            }

            if switcherTrafficLightButtonsVisibility != .never {
                Text("Enabled Buttons")
                VStack(alignment: .leading) {
                    if !switcherEnabledTrafficLightButtons.isEmpty {
                        TrafficLightButtons(
                            displayMode: switcherTrafficLightButtonsVisibility,
                            hoveringOverParentWindow: true,
                            onWindowAction: { _ in },
                            pillStyling: !switcherDisableDockStyleTrafficLights,
                            mockPreviewActive: false,
                            enabledButtons: switcherEnabledTrafficLightButtons,
                            useMonochrome: switcherUseMonochromeTrafficLights
                        )
                    }
                    enabledButtonsCheckboxes(
                        enabledButtons: $switcherEnabledTrafficLightButtons,
                        visibilityBinding: $switcherTrafficLightButtonsVisibility,
                        useMonochrome: switcherUseMonochromeTrafficLights
                    )
                }
                Toggle("Use Monochrome Colors", isOn: $switcherUseMonochromeTrafficLights)

                VStack(alignment: .leading) {
                    Toggle(isOn: $switcherDisableDockStyleTrafficLights) {
                        Text("Disable dock styling on traffic light buttons")
                    }
                    Text("Removes the pill-shaped background styling from traffic light buttons.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }

            Divider().padding(.vertical, 2)
            Text("Window Title").font(.headline).padding(.bottom, -2)

            Toggle("Show Window Title", isOn: $switcherShowWindowTitle)

            if switcherShowWindowTitle {
                Picker("Visibility", selection: $switcherWindowTitleVisibility) {
                    ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                        Text(visibility.localizedName)
                            .tag(visibility)
                    }
                }
            }

            Divider().padding(.vertical, 2)
            Text("Preview Layout (Switcher)").font(.headline).padding(.bottom, -2)
            VStack(alignment: .leading, spacing: 4) {
                let switcherMaxRowsBinding = Binding<Double>(
                    get: { Double(switcherMaxRows) },
                    set: { switcherMaxRows = Int($0) }
                )
                sliderSetting(title: "Max Rows",
                              value: switcherMaxRowsBinding,
                              range: 1.0 ... 8.0,
                              step: 1.0,
                              unit: "",
                              formatter: {
                                  let f = NumberFormatter()
                                  f.minimumFractionDigits = 0
                                  f.maximumFractionDigits = 0
                                  return f
                              }())

                Text(String(localized: "Controls how many rows of windows are shown in the window switcher. Windows are distributed across rows automatically."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var cmdTabPreviewSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            // App Header section
            Toggle("Show App Header", isOn: $cmdTabShowAppName)

            if cmdTabShowAppName {
                Picker("App Header Style", selection: $cmdTabAppNameStyle) {
                    ForEach(AppNameStyle.allCases, id: \.self) { style in
                        Text(style.localizedName)
                            .tag(style)
                    }
                }
                Toggle("Show App Icon Only", isOn: $cmdTabShowAppIconOnly)
            }

            // Toolbar section
            Divider().padding(.vertical, 2)
            Text("Cmd+Tab Toolbar").font(.headline).padding(.bottom, -2)

            Picker("Position Window Controls", selection: $cmdTabControlPosition) {
                ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Toggle("Show Window Title", isOn: $cmdTabShowWindowTitle)

            if cmdTabShowWindowTitle {
                Picker("Window Title Visibility", selection: $cmdTabWindowTitleVisibility) {
                    ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                        Text(visibility.localizedName)
                            .tag(visibility)
                    }
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $cmdTabDisableDockStyleTitles) {
                        Text("Disable dock styling on window titles")
                    }
                    Text("Removes the pill-shaped background styling from window titles.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }
            }

            // Traffic Light Buttons section
            Divider().padding(.vertical, 2)
            Text("Traffic Light Buttons").font(.headline).padding(.bottom, -2)

            Picker("Visibility", selection: $cmdTabTrafficLightButtonsVisibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility)
                }
            }

            if cmdTabTrafficLightButtonsVisibility != .never {
                Text("Enabled Buttons")
                VStack(alignment: .leading) {
                    if !cmdTabEnabledTrafficLightButtons.isEmpty {
                        TrafficLightButtons(
                            displayMode: cmdTabTrafficLightButtonsVisibility,
                            hoveringOverParentWindow: true,
                            onWindowAction: { _ in },
                            pillStyling: true,
                            mockPreviewActive: false,
                            enabledButtons: cmdTabEnabledTrafficLightButtons,
                            useMonochrome: cmdTabUseMonochromeTrafficLights
                        )
                    }
                    enabledButtonsCheckboxes(
                        enabledButtons: $cmdTabEnabledTrafficLightButtons,
                        visibilityBinding: $cmdTabTrafficLightButtonsVisibility,
                        useMonochrome: cmdTabUseMonochromeTrafficLights
                    )
                }
                Toggle("Use Monochrome Colors", isOn: $cmdTabUseMonochromeTrafficLights)

                VStack(alignment: .leading) {
                    Toggle(isOn: $cmdTabDisableDockStyleTrafficLights) {
                        Text("Disable dock styling on traffic light buttons")
                    }
                    Text("Removes the pill-shaped background styling from traffic light buttons.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }
            }

            // Layout section
            Divider().padding(.vertical, 2)
            Text("Cmd+Tab Layout").font(.headline).padding(.bottom, -2)

            VStack(alignment: .leading) {
                Toggle(isOn: $cmdTabUseEmbeddedDockPreviewElements) {
                    Text("Embed controls in preview frames")
                }
                Text("Places traffic light buttons and window titles directly inside the preview frames.")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }
        }
    }

    private let buttonDescriptions: [(WindowAction, String)] = [
        (.quit, String(localized: "Quit")),
        (.close, String(localized: "Close")),
        (.minimize, String(localized: "Minimize")),
        (.toggleFullScreen, String(localized: "Fullscreen")),
        (.maximize, String(localized: "Maximize")),
        (.openNewWindow, String(localized: "New Window")),
    ]

    @ViewBuilder
    private func enabledButtonsCheckboxes(
        enabledButtons: Binding<Set<WindowAction>>,
        visibilityBinding: Binding<TrafficLightButtonsVisibility>,
        useMonochrome: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ForEach(buttonDescriptions.prefix(3), id: \.0) { action, label in
                    Toggle(isOn: Binding(
                        get: { enabledButtons.wrappedValue.contains(action) },
                        set: { isEnabled in
                            if isEnabled {
                                enabledButtons.wrappedValue.insert(action)
                            } else {
                                enabledButtons.wrappedValue.remove(action)
                                if enabledButtons.wrappedValue.isEmpty {
                                    visibilityBinding.wrappedValue = .never
                                }
                            }
                        }
                    )) {
                        Text(label)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                }
            }
            HStack(spacing: 12) {
                ForEach(buttonDescriptions.suffix(3), id: \.0) { action, label in
                    Toggle(isOn: Binding(
                        get: { enabledButtons.wrappedValue.contains(action) },
                        set: { isEnabled in
                            if isEnabled {
                                enabledButtons.wrappedValue.insert(action)
                            } else {
                                enabledButtons.wrappedValue.remove(action)
                                if enabledButtons.wrappedValue.isEmpty {
                                    visibilityBinding.wrappedValue = .never
                                }
                            }
                        }
                    )) {
                        Text(label)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                }
            }
        }
    }

    private var contextSettingsLabel: LocalizedStringKey {
        switch selectedPreviewContext {
        case .dock:
            "Dock Preview Settings"
        case .windowSwitcher:
            "Window Switcher Settings"
        case .cmdTab:
            "Cmd+Tab Settings"
        }
    }

    private func advancedSettingsToggle(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .center) {
            Text("Fine-tune visual details and layout options.")
                .font(.footnote)
                .foregroundColor(.gray)
            HStack {
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.1)) {
                        showAdvancedAppearanceSettings.toggle()
                        if showAdvancedAppearanceSettings {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.smooth(duration: 0.1)) {
                                    proxy.scrollTo(advancedAppearanceSettingsSectionID, anchor: .top)
                                }
                            }
                        }
                    }
                } label: {
                    Label(showAdvancedAppearanceSettings ? "Hide Advanced Settings" : "Show Advanced Settings", systemImage: showAdvancedAppearanceSettings ? "chevron.up.circle" : "chevron.down.circle")
                }
                .buttonStyle(AccentButtonStyle())
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var advancedAppearanceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            StyledGroupBox(label: "Window Background") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("All window previews show a gray background. When hovered, the background changes to the accent color or custom color below.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        ColorPicker("Custom Hover Highlight Color", selection: Binding(
                            get: { hoverHighlightColor ?? Color(nsColor: .controlAccentColor) },
                            set: { hoverHighlightColor = $0 }
                        ))
                        Button(action: {
                            Defaults.reset(.hoverHighlightColor)
                        }) {
                            Text("Reset")
                        }
                        .buttonStyle(AccentButtonStyle(small: true))
                    }

                    sliderSetting(title: "Background Opacity",
                                  value: $selectionOpacity,
                                  range: 0 ... 1,
                                  step: 0.05,
                                  unit: "",
                                  formatter: NumberFormatter.percentFormatter)
                }
            }

            StyledGroupBox(label: "Dock Preview Transparency") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Control the transparency of the dock preview background. Lower values make the preview more transparent, which can help prevent it from blocking window content.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    sliderSetting(title: "Background Opacity",
                                  value: $dockPreviewBackgroundOpacity,
                                  range: 0 ... 1.0,
                                  step: 0.05,
                                  unit: "",
                                  formatter: NumberFormatter.percentFormatter)
                }
            }

            StyledGroupBox(label: "Color Customization") {
                GradientColorPaletteSettingsView()
            }
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    private func compactThresholdSlider(title: String, value: Binding<Int>, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue == 0 ? "Disabled" : "\(value.wrappedValue)+ windows")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0) }
                ),
                in: 0 ... 10,
                step: 1
            )

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    struct WindowSizeSliderView: View {
        @Default(.previewWidth) var previewWidth
        @Default(.previewHeight) var previewHeight
        @Default(.lockAspectRatio) var lockAspectRatio

        private let aspectRatio: CGFloat = 16.0 / 10.0

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $lockAspectRatio) {
                    Text("Lock aspect ratio (16:10)")
                }
                .onChange(of: lockAspectRatio) { newValue in
                    if newValue {
                        // When locking, adjust height to match 16:10 ratio
                        previewHeight = previewWidth / aspectRatio
                    }
                    updateWindowSize()
                }

                sliderSetting(
                    title: "Preview Width",
                    value: $previewWidth,
                    range: 100.0 ... 600.0,
                    step: 10.0,
                    unit: "px",
                    formatter: {
                        let f = NumberFormatter()
                        f.minimumFractionDigits = 0
                        f.maximumFractionDigits = 0
                        return f
                    }()
                )
                .onChange(of: previewWidth) { _ in
                    if lockAspectRatio {
                        previewHeight = previewWidth / aspectRatio
                    }
                    updateWindowSize()
                }

                sliderSetting(
                    title: "Preview Height",
                    value: $previewHeight,
                    range: 60.0 ... 400.0,
                    step: 10.0,
                    unit: "px",
                    formatter: {
                        let f = NumberFormatter()
                        f.minimumFractionDigits = 0
                        f.maximumFractionDigits = 0
                        return f
                    }()
                )
                .disabled(lockAspectRatio)
                .onChange(of: previewHeight) { _ in
                    if lockAspectRatio {
                        previewWidth = previewHeight * aspectRatio
                    }
                    updateWindowSize()
                }

                Text("Current aspect ratio: \(formatAspectRatio(previewWidth / previewHeight))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }

        private func updateWindowSize() {
            SharedPreviewWindowCoordinator.activeInstance?.windowSize = getWindowSize()
        }

        private func formatAspectRatio(_ ratio: CGFloat) -> String {
            // Common aspect ratios
            let commonRatios: [(ratio: CGFloat, display: String)] = [
                (16.0 / 9.0, "16:9"),
                (16.0 / 10.0, "16:10"),
                (4.0 / 3.0, "4:3"),
                (3.0 / 2.0, "3:2"),
                (21.0 / 9.0, "21:9"),
                (1.0, "1:1"),
            ]

            // Check if it matches a common ratio (within 0.01 tolerance)
            for commonRatio in commonRatios {
                if abs(ratio - commonRatio.ratio) < 0.01 {
                    return commonRatio.display
                }
            }

            // For custom ratios, show as X.XX:1
            return String(format: "%.2f:1", ratio)
        }
    }
}
