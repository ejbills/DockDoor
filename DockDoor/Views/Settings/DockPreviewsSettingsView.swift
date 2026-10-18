import Defaults
import SwiftUI

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
    @Default(.hoverWindowOpenDelay) var hoverWindowOpenDelay
    @Default(.useDelayOnlyForInitialOpen) var useDelayOnlyForInitialOpen
    @Default(.fadeOutDuration) var fadeOutDuration
    @Default(.inactivityTimeout) var inactivityTimeout
    @Default(.preventPreviewReentryDuringFadeOut) var preventPreviewReentryDuringFadeOut

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
                SettingsSection("Appearance") {
                    appearanceRows
                }

                SettingsSection("Window display") {
                    windowDisplayRows
                }

                SettingsSection("Dock interaction") {
                    dockInteractionRows
                }
            }
        } pinnedHeader: {
            if enableDockPreviews {
                SettingsMockPreview(context: .dock, maxHeight: 170)
            }
        }
    }

    // MARK: - Window Display

    private var appHeaderMode: Binding<AppHeaderMode> {
        AppHeaderMode.binding(
            showName: $showAppName,
            showIconOnly: $showAppIconOnly,
            style: $appNameStyle
        )
    }

    @ViewBuilder
    private var windowDisplayRows: some View {
        SharedWindowDisplayRows(
            currentSpaceOnly: $showWindowsFromCurrentSpaceOnly,
            currentSpaceOnlyTarget: "dockPreviews.currentSpaceOnly",
            monitorCaption: "Only display windows that are on the same display as the Dock icon you're hovering.",
            currentMonitorOnly: $showWindowsFromCurrentMonitorOnly,
            currentMonitorOnlyTarget: "dockPreviews.currentMonitorOnly",
            includeHidden: $includeHiddenWindowsInDockPreview,
            includeHiddenTarget: "dockPreviews.includeHidden",
            showWindowless: $showWindowlessAppsInDockPreview,
            showWindowlessTarget: "dockPreviews.showWindowless",
            windowlessTitle: "Show preview for apps with no open windows",
            windowlessCaption: "Show a placeholder preview when hovering dock apps that have no windows.",
            ignoreSingleWindow: $ignoreAppsWithSingleWindow,
            ignoreSingleWindowTarget: "dockPreviews.ignoreSingleWindow",
            ignoreSingleWindowCaption: "Prevents apps that only ever have a single window from appearing in previews."
        )

        Picker("Window sort order", selection: $windowPreviewSortOrder) {
            ForEach(WindowPreviewSortOrder.allCases.filter { !$0.isWindowSwitcherOnly }) { order in
                Text(order.localizedName).tag(order)
            }
        }
        .settingsSearchTarget("dockPreviews.sortOrder")

        Toggle(isOn: $keepPreviewOnAppTerminate) { Text("Keep preview when app terminates") }
            .settingsSearchTarget("dockPreviews.keepOnTerminate")
            .settingsAnnotation("Remove only terminated app's windows instead of hiding the entire preview.")

        Toggle(isOn: $groupAppInstancesInDock) { Text("Group multiple app instances together") }
            .settingsSearchTarget("dockPreviews.groupInstances")
            .settingsAnnotation("Show windows from all instances of an app when hovering its dock icon.")

        Toggle(isOn: $collapseNativeTabsIntoSingleWindow) { Text("Collapse native tabs into a single window") }
            .settingsSearchTarget("dockPreviews.collapseNativeTabs")
            .settingsAnnotation("Show one preview for apps that use native macOS window tabs (e.g. Ghostty, Finder, Terminal) instead of one preview per tab.", more: "Restart the app for this to take effect.")
    }

    // MARK: - Dock Interaction

    /// Maps the hide-on-click flag and its action onto one picker.
    private var dockIconClickChoice: Binding<DockIconClickChoice> {
        Binding {
            guard shouldHideOnDockItemClick else { return .nothing }
            return dockClickAction == .hide ? .hide : .minimize
        } set: { choice in
            switch choice {
            case .nothing:
                shouldHideOnDockItemClick = false
            case .minimize:
                shouldHideOnDockItemClick = true
                dockClickAction = .minimize
            case .hide:
                shouldHideOnDockItemClick = true
                dockClickAction = .hide
            }
        }
    }

    @ViewBuilder
    private var dockInteractionRows: some View {
        Picker("Dock Preview Trigger", selection: $dockPreviewActivationMode) {
            ForEach(DockPreviewActivationMode.allCases, id: \.self) {
                Text($0.localizedName).tag($0)
            }
        }
        .settingsSearchTarget("dockPreviews.activationTrigger")
        .settingsAnnotation("Show previews automatically on hover, or require a click trigger on the Dock icon.")

        if dockPreviewActivationMode == .modifierClick {
            Picker("Dock Preview Modifier", selection: $dockPreviewActivationModifier) {
                ForEach(DockPreviewActivationModifier.allCases, id: \.self) {
                    Text($0.localizedName).tag($0)
                }
            }
            .settingsSearchTarget("dockPreviews.activationModifier")
        }

        Picker("Dock Preview Hover Action", selection: $previewHoverAction) {
            ForEach(PreviewHoverAction.allCases, id: \.self) { Text($0.localizedName).tag($0) }
        }
        .settingsSearchTarget("dockPreviews.hoverAction")

        if previewHoverAction == .tap {
            Toggle(isOn: $keepPreviewOnHoverActivation) {
                Text("Keep preview open after hover activation")
            }
            .settingsSearchTarget("dockPreviews.keepOnHoverActivation")
            .settingsAnnotation("Keep Dock previews visible while the pointer remains over them after a hover brings a window to the front.")
        }

        if previewHoverAction != .none {
            SettingsSliderRow(
                title: "Preview Hover Action Delay",
                value: $tapEquivalentInterval,
                range: 0 ... 2,
                defaultValue: 1.5,
                unit: " s",
                step: 0.1,
                decimals: 1
            )
            .settingsSearchTarget("dockPreviews.hoverDelay")
        }

        Picker("Dock icon click", selection: dockIconClickChoice) {
            ForEach(DockIconClickChoice.allCases) { choice in
                Text(choice.localizedName).tag(choice)
            }
        }
        .settingsSearchTarget("dockPreviews.hideOnClick")
        .settingsAnnotation("What clicking the icon of an app that is already in front does to its windows.")

        if shouldHideOnDockItemClick, dockClickAction == .minimize {
            Toggle(isOn: $restoreAllMinimizedWindowsOnDockClick) { Text("Restore all minimized windows on dock icon click") }
                .settingsSearchTarget("dockPreviews.restoreAllMinimizedOnClick")
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

        SettingsSliderRow(
            title: "Preview Window Open Delay",
            value: $hoverWindowOpenDelay,
            range: 0 ... 2,
            defaultValue: 0.2,
            unit: " s",
            step: 0.1,
            decimals: 1
        )
        .settingsSearchTarget("advanced.openDelay")

        Toggle(isOn: $useDelayOnlyForInitialOpen) {
            Text("Only use delay for initial window opening")
        }
        .settingsSearchTarget("advanced.delayOnlyInitial")
        .settingsAnnotation("Switching between dock icons while a preview is already open will show previews instantly.")

        SettingsSliderRow(
            title: "Preview Window Fade Out Duration",
            value: $fadeOutDuration,
            range: 0 ... 2,
            defaultValue: 0.4,
            unit: " s",
            step: 0.1,
            decimals: 1
        )
        .settingsSearchTarget("advanced.fadeOut")

        SettingsSliderRow(
            title: "Preview Window Inactivity Timer",
            value: $inactivityTimeout,
            range: 0 ... 3,
            defaultValue: 0.2,
            unit: " s",
            step: 0.1,
            decimals: 1
        )
        .settingsSearchTarget("advanced.inactivity")

        Toggle(isOn: $preventPreviewReentryDuringFadeOut) {
            Text("Prevent preview reappearance during fade-out")
        }
        .settingsSearchTarget("advanced.preventReentry")
        .settingsAnnotation("Moving the mouse back over the preview during fade-out will not reactivate it.")
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

        Picker("Window title", selection: WindowTitleMode.binding(showTitle: $showWindowTitle, visibility: $windowTitleVisibility)) {
            ForEach(WindowTitleMode.allCases) { mode in
                Text(mode.localizedName).tag(mode)
            }
        }
        .settingsSearchTarget("appearance.dockWindowTitle")

        if showWindowTitle {
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

        SettingsSliderRow(
            title: "Max rows",
            value: Binding<Double>(get: { Double(previewMaxRows) }, set: { previewMaxRows = Int($0) }),
            range: 1.0 ... 8.0,
            defaultValue: 1,
            step: 1
        )
        .settingsSearchTarget("appearance.dockMaxRows")
        .settingsAnnotation("Used when the Dock is at the bottom of the screen.")

        SettingsSliderRow(
            title: "Max columns",
            value: Binding<Double>(get: { Double(previewMaxColumns) }, set: { previewMaxColumns = Int($0) }),
            range: 1.0 ... 8.0,
            defaultValue: 2,
            step: 1
        )
        .settingsSearchTarget("appearance.dockMaxColumns")
        .settingsAnnotation("Used when the Dock is on the left or right of the screen.")
    }
}

private enum DockIconClickChoice: CaseIterable, Identifiable {
    case nothing
    case minimize
    case hide

    var id: Self {
        self
    }

    var localizedName: String {
        switch self {
        case .nothing: String(localized: "Do nothing", comment: "Dock icon click option")
        case .minimize: DockClickAction.minimize.localizedName
        case .hide: DockClickAction.hide.localizedName
        }
    }
}
