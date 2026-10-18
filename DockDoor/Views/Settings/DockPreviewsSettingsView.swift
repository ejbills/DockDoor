import Defaults
import SwiftUI

/// The three header knobs (visibility, style, icon-only) collapse into one
/// picker: these write the shared showAppName / appNameStyle /
/// showAppIconOnly keys, which also drive widget headers.
private enum AppHeaderMode: String, CaseIterable, Identifiable {
    case hidden
    case iconOnly
    case nameAndIcon
    case shadowed
    case popover

    var id: Self {
        self
    }

    var localizedName: String {
        switch self {
        case .hidden: String(localized: "Hidden", comment: "App header option")
        case .iconOnly: String(localized: "Icon only", comment: "App header option")
        case .nameAndIcon: String(localized: "Name and icon", comment: "App header option")
        case .shadowed: String(localized: "Name and icon (shadowed)", comment: "App header option")
        case .popover: String(localized: "Popover", comment: "App header option")
        }
    }
}

struct DockPreviewsSettingsView: View {
    @Default(.enableDockPreviews) var enableDockPreviews
    @Default(.showWindowsFromCurrentSpaceOnly) var showWindowsFromCurrentSpaceOnly
    @Default(.showWindowsFromCurrentMonitorOnly) var showWindowsFromCurrentMonitorOnly
    @Default(.windowPreviewSortOrder) var windowPreviewSortOrder
    @Default(.keepPreviewOnAppTerminate) var keepPreviewOnAppTerminate
    @Default(.groupAppInstancesInDock) var groupAppInstancesInDock
    @Default(.collapseNativeTabsIntoSingleWindow) var collapseNativeTabsIntoSingleWindow
    @Default(.includeHiddenWindowsInDockPreview) var includeHiddenWindowsInDockPreview
    @Default(.showWindowlessAppsInDockPreview) var showWindowlessAppsInDockPreview
    @Default(.dockPreviewActivationMode) var dockPreviewActivationMode
    @Default(.dockPreviewActivationModifier) var dockPreviewActivationModifier
    @Default(.previewHoverAction) var previewHoverAction
    @Default(.keepPreviewOnHoverActivation) var keepPreviewOnHoverActivation
    @Default(.tapEquivalentInterval) var tapEquivalentInterval
    @Default(.shouldHideOnDockItemClick) var shouldHideOnDockItemClick
    @Default(.dockClickAction) var dockClickAction
    @Default(.restoreAllMinimizedWindowsOnDockClick) var restoreAllMinimizedWindowsOnDockClick
    @Default(.enableCmdRightClickQuit) var enableCmdRightClickQuit
    @Default(.quitAppOnWindowClose) var quitAppOnWindowClose
    @Default(.bufferFromDock) var bufferFromDock
    @Default(.ignoreAppsWithSingleWindow) var ignoreAppsWithSingleWindow

    @Default(.showAppName) var showAppName
    @Default(.appNameStyle) var appNameStyle
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.dockPreviewControlPosition) var dockPreviewControlPosition
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleVisibility) var windowTitleVisibility
    @Default(.disableDockStyleTitles) var disableDockStyleTitles
    @Default(.disableDockStyleTrafficLights) var disableDockStyleTrafficLights
    @Default(.showMassActionButtons) var showMassActionButtons
    @Default(.useEmbeddedDockPreviewElements) var useEmbeddedDockPreviewElements
    @Default(.previewMaxColumns) var previewMaxColumns
    @Default(.previewMaxRows) var previewMaxRows
    @Default(.windowTitleFontSize) var windowTitleFontSize

    var body: some View {
        SettingsFormView {
            SettingsSection("Dock previews") {
                Toggle(isOn: $enableDockPreviews) { Text("Enable Dock Previews") }
                    .settingsSearchTarget("dockPreviews.enable")
                    .settingsAnnotation("Show window previews for Dock icons.")
                    .onChange(of: enableDockPreviews) { _ in askUserToRestartApplication() }
            }

            if enableDockPreviews {
                SettingsSection("Window display") {
                    windowDisplayRows
                }

                SettingsSection("Dock interaction") {
                    dockInteractionRows
                }

                SettingsSection("Appearance") {
                    appearanceRows
                }

                SettingsSection("Preview") {
                    SettingsMockPreview(context: .dock)
                }
            }
        }
    }

    // MARK: - Window Display

    private var appHeaderMode: Binding<AppHeaderMode> {
        Binding(
            get: {
                if !showAppName {
                    return .hidden
                }
                if showAppIconOnly {
                    return .iconOnly
                }
                switch appNameStyle {
                case .default: return .nameAndIcon
                case .shadowed: return .shadowed
                case .popover: return .popover
                }
            },
            set: { mode in
                switch mode {
                case .hidden:
                    showAppName = false
                    showAppIconOnly = false
                case .iconOnly:
                    showAppName = true
                    showAppIconOnly = true
                case .nameAndIcon, .shadowed, .popover:
                    showAppName = true
                    showAppIconOnly = false
                    appNameStyle = switch mode {
                    case .nameAndIcon: .default
                    case .shadowed: .shadowed
                    default: .popover
                    }
                }
            }
        )
    }

    @ViewBuilder
    private var windowDisplayRows: some View {
        Toggle(isOn: $showWindowsFromCurrentSpaceOnly) { Text("Show windows from current Space only") }
            .settingsSearchTarget("dockPreviews.currentSpaceOnly")
            .settingsAnnotation("Only display windows that are in the current virtual desktop/Space.")

        Toggle(isOn: $showWindowsFromCurrentMonitorOnly) { Text("Show windows from current monitor only") }
            .settingsSearchTarget("dockPreviews.currentMonitorOnly")
            .settingsAnnotation("Only display windows that are on the same display as the Dock icon you're hovering.")

        Picker("Window sort order", selection: $windowPreviewSortOrder) {
            ForEach(WindowPreviewSortOrder.allCases.filter { !$0.isWindowSwitcherOnly }) { order in
                Text(order.localizedName).tag(order)
            }
        }
        .settingsSearchTarget("dockPreviews.sortOrder")

        Toggle(isOn: $includeHiddenWindowsInDockPreview) { Text("Include hidden/minimized windows") }
            .settingsSearchTarget("dockPreviews.includeHidden")

        Toggle(isOn: $showWindowlessAppsInDockPreview) { Text("Show preview for apps with no open windows") }
            .settingsSearchTarget("dockPreviews.showWindowless")
            .settingsAnnotation("Show a placeholder preview when hovering dock apps that have no windows.")

        Toggle(isOn: $keepPreviewOnAppTerminate) { Text("Keep preview when app terminates") }
            .settingsSearchTarget("dockPreviews.keepOnTerminate")
            .settingsAnnotation("Remove only terminated app's windows instead of hiding the entire preview.")

        Toggle(isOn: $groupAppInstancesInDock) { Text("Group multiple app instances together") }
            .settingsSearchTarget("dockPreviews.groupInstances")
            .settingsAnnotation("Show windows from all instances of an app when hovering its dock icon.")

        Toggle(isOn: $collapseNativeTabsIntoSingleWindow) { Text("Collapse native tabs into a single window") }
            .settingsSearchTarget("dockPreviews.collapseNativeTabs")
            .settingsAnnotation("Show one preview for apps that use native macOS window tabs (e.g. Ghostty, Finder, Terminal) instead of one preview per tab.", more: "Restart the app for this to take effect.")

        Toggle(isOn: $ignoreAppsWithSingleWindow) { Text("Ignore apps with one window") }
            .settingsSearchTarget("dockPreviews.ignoreSingleWindow")
            .settingsAnnotation("Prevents apps that only ever have a single window from appearing in previews.")
    }

    // MARK: - Dock Interaction

    @ViewBuilder
    private var dockInteractionRows: some View {
        Picker("Dock Preview Trigger", selection: $dockPreviewActivationMode) {
            ForEach(DockPreviewActivationMode.allCases, id: \.self) {
                Text($0.localizedName).tag($0)
            }
        }
        .settingsSearchTarget("dockPreviews.activationTrigger")
        .settingsAnnotation("Show previews automatically on hover, or require a click trigger on the Dock icon.")

        Picker("Dock Preview Modifier", selection: $dockPreviewActivationModifier) {
            ForEach(DockPreviewActivationModifier.allCases, id: \.self) {
                Text($0.localizedName).tag($0)
            }
        }
        .settingsSearchTarget("dockPreviews.activationModifier")
        .disabled(dockPreviewActivationMode != .modifierClick)

        Picker("Dock Preview Hover Action", selection: $previewHoverAction) {
            ForEach(PreviewHoverAction.allCases, id: \.self) { Text($0.localizedName).tag($0) }
        }
        .settingsSearchTarget("dockPreviews.hoverAction")

        Toggle(isOn: $keepPreviewOnHoverActivation) {
            Text("Keep preview open after hover activation")
        }
        .disabled(previewHoverAction != .tap)
        .settingsSearchTarget("dockPreviews.keepOnHoverActivation")
        .settingsAnnotation("Keep Dock previews visible while the pointer remains over them after a hover brings a window to the front.")

        SettingsSliderRow(
            title: "Preview Hover Action Delay",
            value: $tapEquivalentInterval,
            range: 0 ... 2,
            defaultValue: 1.5,
            unit: " s",
            step: 0.1,
            decimals: 1
        )
        .disabled(previewHoverAction == .none)
        .settingsSearchTarget("dockPreviews.hoverDelay")

        Toggle(isOn: $shouldHideOnDockItemClick) { Text("Hide all app windows on dock icon click") }
            .settingsSearchTarget("dockPreviews.hideOnClick")

        if shouldHideOnDockItemClick {
            Picker("Dock Click Action", selection: $dockClickAction) {
                ForEach(DockClickAction.allCases, id: \.self) {
                    Text($0.localizedName).tag($0)
                }
            }

            if dockClickAction == .minimize {
                Toggle(isOn: $restoreAllMinimizedWindowsOnDockClick) { Text("Restore all minimized windows on dock icon click") }
                    .settingsSearchTarget("dockPreviews.restoreAllMinimizedOnClick")
            }
        }

        Toggle(isOn: $enableCmdRightClickQuit) { Text("CMD + Right Click on dock icon to quit app") }
            .settingsSearchTarget("dockPreviews.cmdRightClickQuit")

        Toggle(isOn: $quitAppOnWindowClose) { Text("Quit app when closing its last window") }
            .settingsSearchTarget("dockPreviews.quitOnClose")
            .settingsAnnotation("When an app has only one window left, closing it will quit the app. Useful as a replacement for Swift Quit.")

        SettingsSliderRow(
            title: "Window Buffer from Dock (pixels)",
            value: $bufferFromDock,
            range: -100 ... 100,
            unit: " px",
            step: 5
        )
        .settingsSearchTarget("dockPreviews.buffer")
    }

    // MARK: - Appearance

    @ViewBuilder
    private var appearanceRows: some View {
        Picker("App header", selection: appHeaderMode) {
            ForEach(AppHeaderMode.allCases) { mode in
                Text(mode.localizedName).tag(mode)
            }
        }
        .settingsSearchTarget("appearance.dockAppHeader")
        .settingsAnnotation("Show the app name and icon above dock previews. Shared with widget headers.")

        Picker("Position Dock Preview Controls", selection: $dockPreviewControlPosition) {
            ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                Text(position.localizedName)
                    .tag(position)
            }
        }
        .settingsSearchTarget("appearance.dockControlPosition")

        Toggle(isOn: $showWindowTitle) { Text("Show Window Title") }
            .settingsSearchTarget("appearance.dockShowWindowTitle")

        if showWindowTitle {
            Picker("Window Title Visibility", selection: $windowTitleVisibility) {
                ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility)
                }
            }
            .settingsSearchTarget("appearance.dockWindowTitleVisibility")

            Toggle(isOn: $disableDockStyleTitles) { Text("Disable dock styling on window titles") }
                .settingsSearchTarget("appearance.dockDisableTitleStyling")
                .settingsAnnotation("Removes the pill-shaped background styling from window titles in dock previews for a cleaner look.")

            Picker("Window Title Font Size", selection: $windowTitleFontSize) {
                ForEach(WindowTitleFontSize.allCases) { size in
                    Text(size.localizedName)
                        .tag(size)
                }
            }
            .settingsSearchTarget("appearance.dockWindowTitleFontSize")
        }

        AppearanceSettingsView.TrafficLightButtonsSettingsView()

        Toggle(isOn: $disableDockStyleTrafficLights) { Text("Disable dock styling on traffic light buttons") }
            .settingsSearchTarget("appearance.dockDisableTrafficLightStyling")
            .settingsAnnotation("Removes the pill-shaped background styling from traffic light buttons in dock previews for a cleaner look.")

        Toggle(isOn: $showMassActionButtons) { Text("Show Close All and Minimize All buttons") }
            .settingsSearchTarget("appearance.dockMassActionButtons")
            .settingsAnnotation("Displays Close All and Minimize All buttons when hovering the app icon in dock previews.")

        Toggle(isOn: $useEmbeddedDockPreviewElements) { Text("Embed controls in preview frames") }
            .settingsSearchTarget("appearance.dockEmbedControls")
            .settingsAnnotation("Places traffic light buttons and window titles directly inside the dock preview frames for a more compact and minimal appearance.")

        VStack(alignment: .leading, spacing: 4) {
            SettingsSliderRow(
                title: "Max Rows (Bottom Dock)",
                value: Binding<Double>(
                    get: { Double(previewMaxRows) },
                    set: { previewMaxRows = Int($0) }
                ),
                range: 1.0 ... 8.0,
                defaultValue: 1,
                step: 1
            )
            .settingsSearchTarget("appearance.dockMaxRows")

            SettingsSliderRow(
                title: "Max Columns (Left/Right Dock)",
                value: Binding<Double>(
                    get: { Double(previewMaxColumns) },
                    set: { previewMaxColumns = Int($0) }
                ),
                range: 1.0 ... 8.0,
                defaultValue: 2,
                step: 1
            )
            .settingsSearchTarget("appearance.dockMaxColumns")
        }
        .settingsAnnotation("Controls how many rows/columns of windows are shown in dock previews. Only the relevant setting applies based on dock position.")
    }
}
