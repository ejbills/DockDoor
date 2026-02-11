import AppKit
import Defaults
import LaunchAtLogin
import SwiftUI
import UniformTypeIdentifiers

struct MainSettingsView: View {
    @Default(.showMenuBarIcon) var showMenuBarIcon
    @Default(.showAnimations) var showAnimations
    @Default(.ignoreAppsWithSingleWindow) var ignoreAppsWithSingleWindow
    @Default(.sortMinimizedToEnd) var sortMinimizedToEnd

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 24) {
                supportAndContributionsSection
                applicationBasicsSection
                activeAppIndicatorSection

                HStack {
                    Spacer()
                    Button("Reset All Settings to Defaults") { showResetConfirmation() }
                    Button("Quit DockDoor") { (NSApplication.shared.delegate as! AppDelegate).quitApp() }
                    Spacer()
                }
                .padding(.top, 5)
            }
        }
    }

    // MARK: - Support & Contributions

    private var supportAndContributionsSection: some View {
        SettingsGroup(header: "Support & Contributions", compact: true) {
            SupportLinksSection()
        }
    }

    // MARK: - Application Basics

    private var applicationBasicsSection: some View {
        SettingsGroup(header: "Application Basics") {
            VStack(alignment: .leading, spacing: 10) {
                LaunchAtLogin.Toggle(String(localized: "Launch DockDoor at login"))

                Toggle(isOn: $showMenuBarIcon, label: { Text("Show menu bar icon") })
                    .onChange(of: showMenuBarIcon) { isOn in
                        let appDelegate = NSApplication.shared.delegate as! AppDelegate
                        if isOn { appDelegate.setupMenuBar() } else { appDelegate.removeMenuBar() }
                    }

                Toggle(isOn: Binding(
                    get: { !showAnimations },
                    set: { showAnimations = !$0 }
                )) {
                    Text("Reduce motion")
                }

                Toggle(isOn: $ignoreAppsWithSingleWindow, label: {
                    Text("Ignore apps with one window")
                })
                Text("Prevents apps that only ever have a single window from appearing in previews.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $sortMinimizedToEnd, label: {
                    Text("Sort minimized/hidden windows to end")
                })
                Text("Minimized and hidden windows will appear after all visible windows in previews and switcher.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    // MARK: - Active App Indicator

    private var activeAppIndicatorSection: some View {
        SettingsGroup(header: "Active App Indicator") {
            ActiveAppIndicatorSettingsView()
        }
    }

    // MARK: - Helper Functions

    private func showResetConfirmation() {
        MessageUtil.showAlert(title: String(localized: "Reset to Defaults"), message: String(localized: "Are you sure you want to reset all settings to their default values?"), actions: [.ok, .cancel]) { action in
            if action == .ok {
                Defaults.removeAll()
                Defaults[.launched] = true

                Defaults[.hoverWindowOpenDelay] = Defaults.Keys.hoverWindowOpenDelay.defaultValue
                Defaults[.fadeOutDuration] = Defaults.Keys.fadeOutDuration.defaultValue
                Defaults[.tapEquivalentInterval] = Defaults.Keys.tapEquivalentInterval.defaultValue
                Defaults[.preventDockHide] = Defaults.Keys.preventDockHide.defaultValue
                Defaults[.screenCaptureCacheLifespan] = Defaults.Keys.screenCaptureCacheLifespan.defaultValue
                Defaults[.windowPreviewImageScale] = Defaults.Keys.windowPreviewImageScale.defaultValue
                Defaults[.bufferFromDock] = Defaults.Keys.bufferFromDock.defaultValue
                Defaults[.shouldHideOnDockItemClick] = Defaults.Keys.shouldHideOnDockItemClick.defaultValue
                Defaults[.dockClickAction] = Defaults.Keys.dockClickAction.defaultValue
                Defaults[.enableCmdRightClickQuit] = Defaults.Keys.enableCmdRightClickQuit.defaultValue
                Defaults[.previewHoverAction] = Defaults.Keys.previewHoverAction.defaultValue

                showMenuBarIcon = Defaults.Keys.showMenuBarIcon.defaultValue
                Defaults[.enableWindowSwitcher] = Defaults.Keys.enableWindowSwitcher.defaultValue
                Defaults[.instantWindowSwitcher] = Defaults.Keys.instantWindowSwitcher.defaultValue
                Defaults[.includeHiddenWindowsInSwitcher] = Defaults.Keys.includeHiddenWindowsInSwitcher.defaultValue
                Defaults[.useClassicWindowOrdering] = Defaults.Keys.useClassicWindowOrdering.defaultValue
                Defaults[.limitSwitcherToFrontmostApp] = Defaults.Keys.limitSwitcherToFrontmostApp.defaultValue
                Defaults[.fullscreenAppBlacklist] = Defaults.Keys.fullscreenAppBlacklist.defaultValue

                Defaults[.UserKeybind] = Defaults.Keys.UserKeybind.defaultValue
                Defaults[.requireShiftTabToGoBack] = Defaults.Keys.requireShiftTabToGoBack.defaultValue
                Defaults[.windowSwitcherPlacementStrategy] = Defaults.Keys.windowSwitcherPlacementStrategy.defaultValue
                Defaults[.pinnedScreenIdentifier] = Defaults.Keys.pinnedScreenIdentifier.defaultValue
                Defaults[.enableShiftWindowSwitcherPlacement] = Defaults.Keys.enableShiftWindowSwitcherPlacement.defaultValue
                Defaults[.windowSwitcherHorizontalOffsetPercent] = Defaults.Keys.windowSwitcherHorizontalOffsetPercent.defaultValue
                Defaults[.windowSwitcherVerticalOffsetPercent] = Defaults.Keys.windowSwitcherVerticalOffsetPercent.defaultValue
                Defaults[.windowSwitcherAnchorToTop] = Defaults.Keys.windowSwitcherAnchorToTop.defaultValue

                Defaults[.enableDockPreviewGestures] = Defaults.Keys.enableDockPreviewGestures.defaultValue
                Defaults[.dockSwipeTowardsDockAction] = Defaults.Keys.dockSwipeTowardsDockAction.defaultValue
                Defaults[.dockSwipeAwayFromDockAction] = Defaults.Keys.dockSwipeAwayFromDockAction.defaultValue
                Defaults[.gestureSwipeThreshold] = Defaults.Keys.gestureSwipeThreshold.defaultValue
                Defaults[.middleClickAction] = Defaults.Keys.middleClickAction.defaultValue

                Defaults[.cmdShortcut1Key] = Defaults.Keys.cmdShortcut1Key.defaultValue
                Defaults[.cmdShortcut1Action] = Defaults.Keys.cmdShortcut1Action.defaultValue
                Defaults[.cmdShortcut2Key] = Defaults.Keys.cmdShortcut2Key.defaultValue
                Defaults[.cmdShortcut2Action] = Defaults.Keys.cmdShortcut2Action.defaultValue
                Defaults[.cmdShortcut3Key] = Defaults.Keys.cmdShortcut3Key.defaultValue
                Defaults[.cmdShortcut3Action] = Defaults.Keys.cmdShortcut3Action.defaultValue

                Defaults[.alternateKeybindKey] = Defaults.Keys.alternateKeybindKey.defaultValue
                Defaults[.alternateKeybindMode] = Defaults.Keys.alternateKeybindMode.defaultValue

                Defaults[.cmdTabCycleKey] = Defaults.Keys.cmdTabCycleKey.defaultValue
                Defaults[.searchTriggerKey] = Defaults.Keys.searchTriggerKey.defaultValue

                Defaults[.showSpecialAppControls] = Defaults.Keys.showSpecialAppControls.defaultValue
                Defaults[.showBigControlsWhenNoValidWindows] = Defaults.Keys.showBigControlsWhenNoValidWindows.defaultValue
                Defaults[.useEmbeddedMediaControls] = Defaults.Keys.useEmbeddedMediaControls.defaultValue
                Defaults[.enablePinning] = Defaults.Keys.enablePinning.defaultValue
                Defaults[.filteredCalendarIdentifiers] = Defaults.Keys.filteredCalendarIdentifiers.defaultValue
                Defaults[.groupAppInstancesInDock] = Defaults.Keys.groupAppInstancesInDock.defaultValue

                Defaults[.disableImagePreview] = Defaults.Keys.disableImagePreview.defaultValue

                askUserToRestartApplication()
            }
        }
    }
}

struct AddBlacklistAppSheet: View {
    @Binding var isPresented: Bool
    @Binding var appNameToAdd: String
    var onAdd: (String) -> Void

    @State private var selectedAppInfo: String = ""
    @State private var isLoadingAppInfo: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Add App to Blacklist")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("Select an application:")
                    .font(.subheadline)

                Button(action: selectAppFile) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Browse for .app file...")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingAppInfo)

                if isLoadingAppInfo {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Reading app information...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !selectedAppInfo.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected app:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(selectedAppInfo)
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                    }
                }

                Text("This will add the app to the blacklist using its bundle identifier for reliable matching.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    resetState()
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()
            }
        }
        .padding()
        .frame(width: 450, height: 200)
    }

    private func selectAppFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.prompt = "Select Application"
        panel.message = "Choose an application to add to the blacklist"

        if panel.runModal() == .OK, let url = panel.url {
            isLoadingAppInfo = true

            DispatchQueue.global(qos: .userInitiated).async {
                let bundle = Bundle(url: url)
                let appName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent

                let bundleIdentifier = bundle?.bundleIdentifier ?? ""

                DispatchQueue.main.async {
                    let appToAdd: String
                    if !bundleIdentifier.isEmpty {
                        appToAdd = bundleIdentifier
                        selectedAppInfo = "\(appName) (\(bundleIdentifier))"
                    } else {
                        appToAdd = appName
                        selectedAppInfo = appName
                    }

                    onAdd(appToAdd)
                    resetState()
                    isPresented = false
                    isLoadingAppInfo = false
                }
            }
        }
    }

    private func resetState() {
        appNameToAdd = ""
        selectedAppInfo = ""
        isLoadingAppInfo = false
    }
}
