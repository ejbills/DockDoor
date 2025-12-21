import AppKit
import Defaults
import LaunchAtLogin
import SwiftUI
import UniformTypeIdentifiers

enum SettingsProfile: String, CaseIterable, Identifiable {
    case `default`, snappy, relaxed
    var id: String { rawValue }
    var displayName: LocalizedStringKey {
        switch self {
        case .default: "Default"
        case .snappy: "Snappy"
        case .relaxed: "Relaxed"
        }
    }

    var iconName: String {
        switch self {
        case .default: "slider.horizontal.3"
        case .snappy: "hare.fill"
        case .relaxed: "tortoise.fill"
        }
    }

    var settings: PerformanceProfileSettingsValues {
        switch self {
        case .default:
            PerformanceProfileSettingsValues(
                hoverWindowOpenDelay: Defaults.Keys.hoverWindowOpenDelay.defaultValue,
                fadeOutDuration: Defaults.Keys.fadeOutDuration.defaultValue,
                tapEquivalentInterval: Defaults.Keys.tapEquivalentInterval.defaultValue,
                preventDockHide: Defaults.Keys.preventDockHide.defaultValue
            )
        case .snappy:
            PerformanceProfileSettingsValues(hoverWindowOpenDelay: CoreDockGetAutoHideEnabled() ? 0.1 : 0, fadeOutDuration: 0.15, tapEquivalentInterval: 0.5, preventDockHide: false)
        case .relaxed:
            PerformanceProfileSettingsValues(hoverWindowOpenDelay: 0.25, fadeOutDuration: 0.5, tapEquivalentInterval: 1.5, preventDockHide: true)
        }
    }
}

struct PerformanceProfileSettingsValues {
    let hoverWindowOpenDelay: CGFloat
    let fadeOutDuration: CGFloat
    let tapEquivalentInterval: CGFloat
    let preventDockHide: Bool
}

enum PreviewQualityProfile: String, CaseIterable, Identifiable {
    case detailed, standard, lightweight
    var id: String { rawValue }
    var displayName: LocalizedStringKey {
        switch self {
        case .detailed: "Detailed"
        case .standard: "Standard"
        case .lightweight: "Lightweight"
        }
    }

    var iconName: String {
        switch self {
        case .detailed: "sparkles"
        case .standard: "eye.fill"
        case .lightweight: "leaf.fill"
        }
    }

    var settings: PreviewQualitySettingsValues {
        switch self {
        case .detailed: PreviewQualitySettingsValues(screenCaptureCacheLifespan: 0, windowPreviewImageScale: 1)
        case .standard: PreviewQualitySettingsValues(screenCaptureCacheLifespan: Defaults.Keys.screenCaptureCacheLifespan.defaultValue, windowPreviewImageScale: 2)
        case .lightweight: PreviewQualitySettingsValues(screenCaptureCacheLifespan: 60, windowPreviewImageScale: 4)
        }
    }
}

struct PreviewQualitySettingsValues {
    let screenCaptureCacheLifespan: CGFloat
    let windowPreviewImageScale: CGFloat
}

struct MainSettingsView: View {
    @Default(.showMenuBarIcon) var showMenuBarIcon
    @Default(.enableWindowSwitcher) var enableWindowSwitcher
    @Default(.instantWindowSwitcher) var instantWindowSwitcher
    @Default(.enableWindowSwitcherSearch) var enableWindowSwitcherSearch
    @Default(.searchFuzziness) var searchFuzziness
    @Default(.enableDockPreviews) var enableDockPreviews
    @Default(.showWindowsFromCurrentSpaceOnly) var showWindowsFromCurrentSpaceOnly
    @Default(.windowPreviewSortOrder) var windowPreviewSortOrder
    @Default(.showWindowsFromCurrentSpaceOnlyInSwitcher) var showWindowsFromCurrentSpaceOnlyInSwitcher
    @Default(.windowSwitcherSortOrder) var windowSwitcherSortOrder
    @Default(.showWindowsFromCurrentSpaceOnlyInCmdTab) var showWindowsFromCurrentSpaceOnlyInCmdTab
    @Default(.cmdTabSortOrder) var cmdTabSortOrder
    @Default(.sortMinimizedToEnd) var sortMinimizedToEnd
    @Default(.keepPreviewOnAppTerminate) var keepPreviewOnAppTerminate
    @Default(.enableCmdTabEnhancements) var enableCmdTabEnhancements
    @Default(.enableMouseHoverInSwitcher) var enableMouseHoverInSwitcher
    @Default(.includeHiddenWindowsInSwitcher) var includeHiddenWindowsInSwitcher
    @Default(.useClassicWindowOrdering) var useClassicWindowOrdering
    @Default(.limitSwitcherToFrontmostApp) var limitSwitcherToFrontmostApp
    @Default(.fullscreenAppBlacklist) var fullscreenAppBlacklist
    @Default(.groupAppInstancesInDock) var groupAppInstancesInDock

    @State private var selectedPerformanceProfile: SettingsProfile = .default
    @State private var selectedPreviewQualityProfile: PreviewQualityProfile = .standard
    @State private var showAdvancedSettings: Bool = false
    @State private var showPlacementSettings: Bool = false
    @FocusState private var isKeepAliveFieldFocused: Bool
    @State private var lastKeepAliveDuration: Int = 5

    @Default(.hoverWindowOpenDelay) var hoverWindowOpenDelay
    @Default(.useDelayOnlyForInitialOpen) var useDelayOnlyForInitialOpen
    @Default(.fadeOutDuration) var fadeOutDuration
    @Default(.preventPreviewReentryDuringFadeOut) var preventPreviewReentryDuringFadeOut
    @Default(.inactivityTimeout) var inactivityTimeout
    @Default(.tapEquivalentInterval) var tapEquivalentInterval
    @Default(.preventDockHide) var preventDockHide
    @Default(.preventSwitcherHide) var preventSwitcherHide
    @Default(.ignoreAppsWithSingleWindow) var ignoreAppsWithSingleWindow
    @Default(.screenCaptureCacheLifespan) var screenCaptureCacheLifespan
    @Default(.windowProcessingDebounceInterval) var windowProcessingDebounceInterval
    @Default(.windowPreviewImageScale) var windowPreviewImageScale
    @Default(.windowImageCaptureQuality) var windowImageCaptureQuality
    @Default(.enableLivePreview) var enableLivePreview
    @Default(.enableLivePreviewForDock) var enableLivePreviewForDock
    @Default(.enableLivePreviewForWindowSwitcher) var enableLivePreviewForWindowSwitcher
    @Default(.dockLivePreviewQuality) var dockLivePreviewQuality
    @Default(.dockLivePreviewFrameRate) var dockLivePreviewFrameRate
    @Default(.windowSwitcherLivePreviewQuality) var windowSwitcherLivePreviewQuality
    @Default(.windowSwitcherLivePreviewFrameRate) var windowSwitcherLivePreviewFrameRate
    @Default(.windowSwitcherLivePreviewScope) var windowSwitcherLivePreviewScope
    @Default(.livePreviewStreamKeepAlive) var livePreviewStreamKeepAlive
    @Default(.bufferFromDock) var bufferFromDock
    @Default(.shouldHideOnDockItemClick) var shouldHideOnDockItemClick
    @Default(.dockClickAction) var dockClickAction
    @Default(.enableCmdRightClickQuit) var enableCmdRightClickQuit
    @Default(.previewHoverAction) var previewHoverAction
    @Default(.showAnimations) var showAnimations
    @Default(.raisedWindowLevel) var raisedWindowLevel
    @Default(.disableImagePreview) var disableImagePreview
    @Default(.windowSwitcherPlacementStrategy) var placementStrategy
    @Default(.pinnedScreenIdentifier) var pinnedScreenIdentifier
    @Default(.windowSwitcherHorizontalOffsetPercent) var windowSwitcherHorizontalOffsetPercent
    @Default(.windowSwitcherVerticalOffsetPercent) var windowSwitcherVerticalOffsetPercent
    @Default(.windowSwitcherAnchorToTop) var windowSwitcherAnchorToTop
    @Default(.enableShiftWindowSwitcherPlacement) var enableShiftWindowSwitcherPlacement
    @StateObject private var permissionsChecker = PermissionsChecker()

    private let advancedSettingsSectionID = "advancedSettingsSection"

    var body: some View {
        ScrollViewReader { proxy in
            BaseSettingsView {
                VStack(alignment: .leading, spacing: 16) {
                    supportAndContributionsSection
                    applicationBasicsSection
                    performanceProfilesSection
                    previewQualityProfilesSection
                    advancedSettingsToggle(proxy: proxy)
                    if showAdvancedSettings {
                        advancedSettingsSection.id(advancedSettingsSectionID)
                    }
                }
            }
        }
        .onAppear {
            if doesCurrentSettingsMatchPerformanceProfile(.snappy) { selectedPerformanceProfile = .snappy }
            else if doesCurrentSettingsMatchPerformanceProfile(.relaxed) { selectedPerformanceProfile = .relaxed }
            else if doesCurrentSettingsMatchPerformanceProfile(.default) { selectedPerformanceProfile = .default }

            if doesCurrentSettingsMatchPreviewQualityProfile(.detailed) { selectedPreviewQualityProfile = .detailed }
            else if doesCurrentSettingsMatchPreviewQualityProfile(.lightweight) { selectedPreviewQualityProfile = .lightweight }
            else if doesCurrentSettingsMatchPreviewQualityProfile(.standard) { selectedPreviewQualityProfile = .standard }

            if livePreviewStreamKeepAlive > 0 {
                lastKeepAliveDuration = livePreviewStreamKeepAlive
            }
        }
    }

    private var supportAndContributionsSection: some View {
        StyledGroupBox(label: "Support & Contributions") {
            VStack(alignment: .leading, spacing: 12) {
                Link(destination: URL(string: "https://www.buymeacoffee.com/keplercafe")!) {
                    HStack(spacing: 14) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .padding(8)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange, Color.yellow.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Buy me a coffee")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Support development with a small donation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange.opacity(0.5), Color.yellow.opacity(0.3)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Link(destination: URL(string: "https://discord.gg/TZeRs73hFb")!) {
                    HStack(spacing: 14) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .padding(8)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple, Color.indigo.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Join our Discord")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Discuss features and get help from the community")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple.opacity(0.5), Color.indigo.opacity(0.3)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Link(destination: URL(string: "https://crowdin.com/project/dockdoor/invite?h=895e3c085646d3c07fa36a97044668e02149115")!) {
                    HStack(spacing: 14) {
                        Image(systemName: "globe")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .padding(8)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.teal.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Contribute translation")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Help make DockDoor available in your language")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.5), Color.teal.opacity(0.3)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())

                Link(destination: URL(string: "https://github.com/ejbills/DockDoor/graphs/contributors")!) {
                    HStack {
                        Spacer()
                        Text("Thank you to all contributors ❤️")
                            .font(.subheadline)
                            .foregroundColor(Color.primary.opacity(0.8))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
            }
        }
    }

    private var applicationBasicsSection: some View {
        StyledGroupBox(label: "Application Basics") {
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

                Divider()

                SettingsIllustratedRow(imageName: "DockPreviews") {
                    Toggle(isOn: $enableDockPreviews) { Text("Enable Dock Previews") }
                        .onChange(of: enableDockPreviews) { _ in askUserToRestartApplication() }
                    Text("Show window previews when hovering over Dock icons.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                    if enableDockPreviews {
                        Toggle(isOn: $showWindowsFromCurrentSpaceOnly) { Text("Show windows from current Space only") }
                            .padding(.leading, 20)
                        Text("Only display windows that are in the current virtual desktop/Space.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 40)

                        Text("Window sort order")
                            .padding(.leading, 20)
                        Picker("", selection: $windowPreviewSortOrder) {
                            ForEach(WindowPreviewSortOrder.allCases.filter { !$0.isWindowSwitcherOnly }) { order in
                                Text(order.localizedName).tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.leading, 40)
                        Text("Choose how windows are sorted in the preview.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 40)

                        Toggle(isOn: $keepPreviewOnAppTerminate) { Text("Keep preview when app terminates") }
                            .padding(.leading, 20)
                        Text("When an app terminates, remove only its windows from the preview instead of hiding the entire preview.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 40)
                    }
                }

                Divider()

                SettingsIllustratedRow(imageName: "WindowSwitcher") {
                    Toggle(isOn: $enableWindowSwitcher) { Text("Enable Window Switcher") }
                        .onChange(of: enableWindowSwitcher) { _ in askUserToRestartApplication() }
                    Text("The Window Switcher (often Alt/Cmd-Tab) lets you quickly cycle between open app windows with a keyboard shortcut.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                    if enableWindowSwitcher {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $instantWindowSwitcher) { Text("Show Window Switcher instantly") }
                            Text("Skip the small delay before the switcher appears. May feel snappier but can cause flickering if you quickly release the key.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                            Toggle(isOn: $includeHiddenWindowsInSwitcher) { Text("Include hidden/minimized windows in Switcher") }
                            Toggle(isOn: $enableWindowSwitcherSearch) { Text("Enable search while using Window Switcher") }
                            if enableWindowSwitcherSearch {
                                HStack {
                                    Text("Search Fuzziness")
                                    Slider(value: Binding(
                                        get: { Double(searchFuzziness) },
                                        set: { searchFuzziness = Int($0) }
                                    ), in: 1 ... 5, step: 1)
                                    Text("\(searchFuzziness)")
                                        .frame(width: 20)
                                }
                                .padding(.leading, 20)
                                Text("Level 1 is exact match, level 5 is most lenient fuzzy matching.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 20)
                            }

                            Toggle(isOn: Binding(
                                get: { !preventSwitcherHide },
                                set: { preventSwitcherHide = !$0 }
                            )) { Text("Release initializer key to select window in Switcher") }
                            Toggle(isOn: $enableMouseHoverInSwitcher) { Text("Enable mouse hover selection") }
                            Text("Select and scroll to windows when hovering with mouse. Disable for keyboard-only navigation.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                            Toggle(isOn: $useClassicWindowOrdering) { Text("Start on second window in Switcher") }
                            Text("When opening the window switcher, highlight the second window instead of the first.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)

                            Toggle(isOn: $limitSwitcherToFrontmostApp) { Text("Limit Window Switcher to active app only") }
                            Text("Only show windows from the currently active/frontmost application.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)

                            Toggle(isOn: $showWindowsFromCurrentSpaceOnlyInSwitcher) { Text("Show windows from current Space only") }
                            Text("Only display windows that are in the current virtual desktop/Space.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)

                            Text("Window sort order")
                            Picker("", selection: $windowSwitcherSortOrder) {
                                ForEach(WindowPreviewSortOrder.allCases) { order in
                                    Text(order.localizedName).tag(order)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.leading, 20)
                            Text("Choose how windows are sorted in the window switcher.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)

                            Button {
                                withAnimation(.snappy(duration: 0.1)) { showPlacementSettings.toggle() }
                            } label: {
                                Label("Placement", systemImage: showPlacementSettings ? "chevron.down" : "chevron.right")
                            }
                            .buttonStyle(AccentButtonStyle(small: true))

                            if showPlacementSettings {
                                Picker("Screen", selection: $placementStrategy) {
                                    ForEach(WindowSwitcherPlacementStrategy.allCases, id: \.self) {
                                        Text($0.localizedName).tag($0)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(.leading, 20)
                                .onChange(of: placementStrategy) { newStrategy in
                                    if newStrategy == .pinnedToScreen, pinnedScreenIdentifier.isEmpty {
                                        pinnedScreenIdentifier = NSScreen.main?.uniqueIdentifier() ?? ""
                                    }
                                }

                                if placementStrategy == .pinnedToScreen {
                                    Picker("Pin to", selection: $pinnedScreenIdentifier) {
                                        ForEach(NSScreen.screens, id: \.self) { screen in
                                            Text(screenDisplayName(screen)).tag(screen.uniqueIdentifier())
                                        }
                                        if !pinnedScreenIdentifier.isEmpty,
                                           !NSScreen.screens.contains(where: { $0.uniqueIdentifier() == pinnedScreenIdentifier })
                                        {
                                            Text("Disconnected Display").tag(pinnedScreenIdentifier)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .padding(.leading, 40)

                                    if !pinnedScreenIdentifier.isEmpty,
                                       !NSScreen.screens.contains(where: { $0.uniqueIdentifier() == pinnedScreenIdentifier })
                                    {
                                        Text("This display is currently disconnected.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 40)
                                    }
                                }

                                Toggle(isOn: $enableShiftWindowSwitcherPlacement) {
                                    Text("Offset position")
                                }
                                .padding(.leading, 20)

                                if enableShiftWindowSwitcherPlacement {
                                    Toggle(isOn: $windowSwitcherAnchorToTop) {
                                        Text("Anchor to top")
                                    }
                                    .padding(.leading, 40)
                                    Text("Top edge stays fixed regardless of switcher size.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 60)

                                    HStack {
                                        Image(systemName: "arrow.up")
                                            .foregroundColor(.secondary)
                                            .frame(width: 16)
                                        Slider(value: $windowSwitcherVerticalOffsetPercent, in: -80 ... 80)
                                        Text("\(Int(windowSwitcherVerticalOffsetPercent))%")
                                            .monospacedDigit()
                                            .frame(width: 45, alignment: .trailing)
                                    }
                                    .padding(.leading, 40)

                                    HStack {
                                        Image(systemName: "arrow.right")
                                            .foregroundColor(.secondary)
                                            .frame(width: 16)
                                        Slider(value: $windowSwitcherHorizontalOffsetPercent, in: -80 ... 80)
                                        Text("\(Int(windowSwitcherHorizontalOffsetPercent))%")
                                            .monospacedDigit()
                                            .frame(width: 45, alignment: .trailing)
                                    }
                                    .padding(.leading, 40)
                                }
                            }
                        }
                        .padding(.leading, 20)
                        .padding(.top, 4)
                    }
                }

                Divider()

                SettingsIllustratedRow(imageName: "CmdTab") {
                    Toggle(isOn: $enableCmdTabEnhancements) { Text("Enable Cmd+Tab Enhancements") }
                        .onChange(of: enableCmdTabEnhancements) { _ in askUserToRestartApplication() }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show previews while holding Cmd+Tab.")
                        Text("Cmd+A cycles through previews (Shift+A cycles backward), Left/Right navigate, Down clears selection.")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                    if enableCmdTabEnhancements {
                        Toggle(isOn: $showWindowsFromCurrentSpaceOnlyInCmdTab) { Text("Show windows from current Space only") }
                            .padding(.leading, 20)
                        Text("Only display windows that are in the current virtual desktop/Space.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 40)

                        Text("Window sort order")
                            .padding(.leading, 20)
                        Picker("", selection: $cmdTabSortOrder) {
                            ForEach(WindowPreviewSortOrder.allCases.filter { !$0.isWindowSwitcherOnly }) { order in
                                Text(order.localizedName).tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.leading, 40)
                        Text("Choose how windows are sorted in Cmd+Tab previews.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 40)
                    }
                }

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

    private var performanceProfilesSection: some View {
        StyledGroupBox(label: "Performance Profiles") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(SettingsProfile.allCases) { profile in
                        Button {
                            withAnimation(.smooth) { selectedPerformanceProfile = profile }
                            applyPerformanceProfileSettings(profile)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: profile.iconName).font(.title2).frame(height: 25)
                                Text(profile.displayName).font(.caption).lineLimit(1)
                            }
                            .padding(.vertical, 10).padding(.horizontal, 5).frame(maxWidth: .infinity)
                            .background(selectedPerformanceProfile == profile ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedPerformanceProfile == profile ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: selectedPerformanceProfile == profile ? 2 : 1))
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
                Text("Adjusts how responsive the app feels and behaves during interaction.").font(.footnote).foregroundColor(.gray)
            }
        }
    }

    private var previewQualityProfilesSection: some View {
        StyledGroupBox(label: "Preview Quality Profiles") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(PreviewQualityProfile.allCases) { profile in
                        Button {
                            withAnimation(.smooth) { selectedPreviewQualityProfile = profile }
                            applyPreviewQualityProfileSettings(profile)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: profile.iconName).font(.title2).frame(height: 25)
                                Text(profile.displayName).font(.caption).lineLimit(1)
                            }
                            .padding(.vertical, 10).padding(.horizontal, 5).frame(maxWidth: .infinity)
                            .background(selectedPreviewQualityProfile == profile ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedPreviewQualityProfile == profile ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: selectedPreviewQualityProfile == profile ? 2 : 1))
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
                Text("Controls the visual detail and update frequency of window previews.").font(.footnote).foregroundColor(.gray)
            }
        }
    }

    private func advancedSettingsToggle(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .center) {
            Text("Select a profile to quickly adjust common performance settings. Choose \"Advanced\" for manual control.")
                .font(.footnote).foregroundColor(.gray)
            HStack {
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.1)) {
                        showAdvancedSettings.toggle()
                        if showAdvancedSettings { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { withAnimation(.smooth(duration: 0.1)) { proxy.scrollTo(advancedSettingsSectionID, anchor: .top) } } }
                    }
                } label: { Label(showAdvancedSettings ? "Hide Advanced Settings" : "Show Advanced Settings", systemImage: showAdvancedSettings ? "chevron.up.circle" : "chevron.down.circle") }
                    .buttonStyle(AccentButtonStyle())
                Spacer()
            }
        }
    }

    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            StyledGroupBox(label: "Performance Tuning (Dock Previews)") {
                VStack(alignment: .leading, spacing: 10) {
                    sliderSetting(title: "Preview Window Open Delay", value: $hoverWindowOpenDelay, range: 0 ... 2, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter)
                    VStack(alignment: .leading) {
                        Toggle(isOn: $useDelayOnlyForInitialOpen) {
                            Text("Only use delay for initial window opening")
                        }
                        Text("When enabled, switching between dock icons while a preview is already open will show previews instantly.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.leading, 20)
                    }
                    sliderSetting(title: "Preview Window Fade Out Duration", value: $fadeOutDuration, range: 0 ... 2, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter)
                    sliderSetting(title: "Preview Window Inactivity Timer", value: $inactivityTimeout, range: 0 ... 3, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter)
                    sliderSetting(title: "Window Processing Debounce Interval", value: $windowProcessingDebounceInterval, range: 0 ... 3, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter, onEditingChanged: { isEditing in
                        if !isEditing {
                            askUserToRestartApplication()
                        }
                    })
                    Toggle(isOn: $preventDockHide) { Text("Prevent dock from hiding during previews") }
                    Toggle(isOn: $raisedWindowLevel) { Text("Show preview above app labels").onChange(of: raisedWindowLevel) { _ in askUserToRestartApplication() }}
                    VStack(alignment: .leading) {
                        Toggle(isOn: $preventPreviewReentryDuringFadeOut) {
                            Text("Prevent preview reappearance during fade-out")
                        }
                        Text("When enabled, moving the mouse back over the preview during fade-out will not reactivate it. You must hover over the dock icon again to show the preview.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.leading, 20)
                    }
                }
            }
            StyledGroupBox(label: "Preview Appearance & Quality") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Window Image Capture Quality", selection: $windowImageCaptureQuality) {
                        ForEach(WindowImageCaptureQuality.allCases, id: \.self) { quality in
                            Text(quality.localizedName).tag(quality)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    sliderSetting(title: "Window Image Cache Lifespan", value: $screenCaptureCacheLifespan, range: 0 ... 60, step: 10, unit: "seconds")
                    sliderSetting(title: "Window Image Resolution Scale (1=Best)", value: $windowPreviewImageScale, range: 1 ... 4, step: 1, unit: "")

                    Divider()

                    Toggle(isOn: $enableLivePreview) { Text("Enable Live Preview (Video)") }
                        .onChange(of: enableLivePreview) { newValue in
                            if !newValue {
                                Task { await LiveCaptureManager.shared.stopAllStreams() }
                            }
                        }
                    Text("When enabled, window previews show live video instead of static screenshots. Uses ScreenCaptureKit for real-time capture.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)

                    if enableLivePreview {
                        // MARK: - Dock Live Preview Settings

                        Toggle(isOn: $enableLivePreviewForDock) { Text("Enable for Dock Preview") }
                            .padding(.leading, 20)

                        if enableLivePreviewForDock {
                            Picker("Dock Quality", selection: $dockLivePreviewQuality) {
                                ForEach(LivePreviewQuality.allCases, id: \.self) { quality in
                                    Text(quality.localizedName).tag(quality)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(.leading, 40)

                            Picker("Dock Frame Rate", selection: $dockLivePreviewFrameRate) {
                                ForEach(LivePreviewFrameRate.allCases, id: \.self) { fps in
                                    Text(fps.localizedName).tag(fps)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(.leading, 40)
                        }

                        Divider()
                            .padding(.leading, 20)

                        // MARK: - Window Switcher Live Preview Settings

                        Toggle(isOn: $enableLivePreviewForWindowSwitcher) { Text("Enable for Window Switcher") }
                            .padding(.leading, 20)

                        if enableLivePreviewForWindowSwitcher {
                            Picker("Switcher Quality", selection: $windowSwitcherLivePreviewQuality) {
                                ForEach(LivePreviewQuality.allCases, id: \.self) { quality in
                                    Text(quality.localizedName).tag(quality)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(.leading, 40)

                            Picker("Switcher Frame Rate", selection: $windowSwitcherLivePreviewFrameRate) {
                                ForEach(LivePreviewFrameRate.allCases, id: \.self) { fps in
                                    Text(fps.localizedName).tag(fps)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(.leading, 40)

                            Picker("Switcher Live Preview Scope", selection: $windowSwitcherLivePreviewScope) {
                                ForEach(WindowSwitcherLivePreviewScope.allCases, id: \.self) { scope in
                                    Text(scope.localizedName).tag(scope)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(.leading, 40)

                            Text(windowSwitcherLivePreviewScope.localizedDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 40)
                        }

                        Divider()
                            .padding(.leading, 20)

                        Text("Higher quality and frame rate use more CPU/GPU resources. Use lower settings for Window Switcher if you experience lag.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)

                        Divider()
                            .padding(.leading, 20)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Stream Keep-Alive Duration")
                                .onTapGesture { isKeepAliveFieldFocused = false }

                            HStack(spacing: 0) {
                                Button(action: {
                                    livePreviewStreamKeepAlive = 0
                                    isKeepAliveFieldFocused = false
                                }) {
                                    Text("Immediately close")
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background(livePreviewStreamKeepAlive == 0 ? Color.accentColor : Color.secondary.opacity(0.15))
                                .foregroundColor(livePreviewStreamKeepAlive == 0 ? .white : .primary)
                                .contentShape(Rectangle())

                                HStack(spacing: 4) {
                                    TextField("", value: Binding(
                                        get: { livePreviewStreamKeepAlive > 0 ? livePreviewStreamKeepAlive : lastKeepAliveDuration },
                                        set: {
                                            let newValue = max(1, $0)
                                            lastKeepAliveDuration = newValue

                                            if livePreviewStreamKeepAlive > 0 {
                                                livePreviewStreamKeepAlive = newValue
                                            }
                                        }
                                    ), formatter: NumberFormatter())
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 40)
                                        .multilineTextAlignment(.center)
                                        .focused($isKeepAliveFieldFocused)
                                        .onChange(of: isKeepAliveFieldFocused) { focused in
                                            if focused, livePreviewStreamKeepAlive <= 0 {
                                                livePreviewStreamKeepAlive = lastKeepAliveDuration
                                            }
                                        }
                                    Text("seconds")
                                        .foregroundColor(livePreviewStreamKeepAlive > 0 ? .white : .primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(livePreviewStreamKeepAlive > 0 ? Color.accentColor : Color.secondary.opacity(0.15))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if livePreviewStreamKeepAlive <= 0 {
                                        livePreviewStreamKeepAlive = lastKeepAliveDuration
                                    }
                                }

                                Button(action: {
                                    livePreviewStreamKeepAlive = -1
                                    isKeepAliveFieldFocused = false
                                }) {
                                    Text("Keep Open")
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .background(livePreviewStreamKeepAlive == -1 ? Color.accentColor : Color.secondary.opacity(0.15))
                                .foregroundColor(livePreviewStreamKeepAlive == -1 ? .white : .primary)
                                .contentShape(Rectangle())
                            }
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: livePreviewStreamKeepAlive) { newValue in
                                if newValue == 0 {
                                    Task { await LiveCaptureManager.shared.stopAllStreams() }
                                }
                            }

                            Text("How long to keep video streams active after closing preview. Longer duration means faster reopening but uses more resources.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .onTapGesture { isKeepAliveFieldFocused = false }
                        }
                        .padding(.leading, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .gesture(TapGesture().onEnded {
                            isKeepAliveFieldFocused = false
                        }, including: .gesture)
                    }
                }
            }
            StyledGroupBox(label: "Interaction & Behavior (Dock Previews)") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $groupAppInstancesInDock) { Text("Group multiple app instances together") }
                    Text("When enabled, hovering over an app in the Dock shows windows from all instances of that app. When disabled, shows only windows from the specific instance under the mouse.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)

                    Divider()

                    Picker("Dock Preview Hover Action", selection: $previewHoverAction) { ForEach(PreviewHoverAction.allCases, id: \.self) { Text($0.localizedName).tag($0) } }.pickerStyle(MenuPickerStyle())
                    sliderSetting(title: "Preview Hover Action Delay", value: $tapEquivalentInterval, range: 0 ... 2, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter).disabled(previewHoverAction == .none)
                    Toggle(isOn: $shouldHideOnDockItemClick) { Text("Hide all app windows on dock icon click") }
                    if shouldHideOnDockItemClick {
                        Picker("Dock Click Action", selection: $dockClickAction) {
                            ForEach(DockClickAction.allCases, id: \.self) {
                                Text($0.localizedName).tag($0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.leading, 20)
                    }
                    Toggle(isOn: $enableCmdRightClickQuit) { Text("CMD + Right Click on dock icon to quit app") }

                    sliderSetting(title: "Window Buffer from Dock (pixels)", value: $bufferFromDock, range: -100 ... 100, step: 5, unit: "px", formatter: { let f = NumberFormatter(); f.allowsFloats = false; f.minimumIntegerDigits = 1; f.maximumFractionDigits = 0; return f }())
                }
            }
            StyledGroupBox(label: "Active App Indicator") {
                ActiveAppIndicatorSettingsView()
            }
        }.padding(.top, 5)
    }

    private func screenDisplayName(_ screen: NSScreen) -> String {
        let isMain = screen == NSScreen.main
        var name = screen.localizedName
        if name.isEmpty {
            if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                name = String(format: NSLocalizedString("Display %u", comment: "Generic display name with CGDirectDisplayID"), displayID)
            } else {
                name = String(localized: "Unknown Display")
            }
        }
        return name + (isMain ? " (Main)" : "")
    }

    private func applyPerformanceProfileSettings(_ profile: SettingsProfile) {
        let settings = profile.settings
        hoverWindowOpenDelay = settings.hoverWindowOpenDelay
        fadeOutDuration = settings.fadeOutDuration
        tapEquivalentInterval = settings.tapEquivalentInterval
        preventDockHide = settings.preventDockHide
    }

    private func doesCurrentSettingsMatchPerformanceProfile(_ profile: SettingsProfile) -> Bool {
        let settings = profile.settings
        return hoverWindowOpenDelay == settings.hoverWindowOpenDelay &&
            fadeOutDuration == settings.fadeOutDuration &&
            tapEquivalentInterval == settings.tapEquivalentInterval &&
            preventDockHide == settings.preventDockHide
    }

    private func applyPreviewQualityProfileSettings(_ profile: PreviewQualityProfile) {
        let settings = profile.settings
        screenCaptureCacheLifespan = settings.screenCaptureCacheLifespan
        windowPreviewImageScale = settings.windowPreviewImageScale
    }

    private func doesCurrentSettingsMatchPreviewQualityProfile(_ profile: PreviewQualityProfile) -> Bool {
        let settings = profile.settings
        return screenCaptureCacheLifespan == settings.screenCaptureCacheLifespan &&
            windowPreviewImageScale == settings.windowPreviewImageScale
    }

    private func showResetConfirmation() {
        MessageUtil.showAlert(title: String(localized: "Reset to Defaults"), message: String(localized: "Are you sure you want to reset all settings to their default values? This will reset advanced settings as well."), actions: [.ok, .cancel]) { action in
            if action == .ok {
                Defaults.removeAll()
                Defaults[.launched] = true

                selectedPerformanceProfile = .default; applyPerformanceProfileSettings(.default)
                selectedPreviewQualityProfile = .standard; applyPreviewQualityProfileSettings(.standard)

                let perfDefault = SettingsProfile.default.settings
                hoverWindowOpenDelay = perfDefault.hoverWindowOpenDelay; fadeOutDuration = perfDefault.fadeOutDuration; tapEquivalentInterval = perfDefault.tapEquivalentInterval; preventDockHide = perfDefault.preventDockHide
                let qualityDefault = PreviewQualityProfile.standard.settings
                screenCaptureCacheLifespan = qualityDefault.screenCaptureCacheLifespan; windowPreviewImageScale = qualityDefault.windowPreviewImageScale
                bufferFromDock = Defaults.Keys.bufferFromDock.defaultValue; shouldHideOnDockItemClick = Defaults.Keys.shouldHideOnDockItemClick.defaultValue; dockClickAction = Defaults.Keys.dockClickAction.defaultValue; enableCmdRightClickQuit = Defaults.Keys.enableCmdRightClickQuit.defaultValue; previewHoverAction = Defaults.Keys.previewHoverAction.defaultValue

                showMenuBarIcon = Defaults.Keys.showMenuBarIcon.defaultValue
                enableWindowSwitcher = Defaults.Keys.enableWindowSwitcher.defaultValue
                instantWindowSwitcher = Defaults.Keys.instantWindowSwitcher.defaultValue
                includeHiddenWindowsInSwitcher = Defaults.Keys.includeHiddenWindowsInSwitcher.defaultValue
                useClassicWindowOrdering = Defaults.Keys.useClassicWindowOrdering.defaultValue
                limitSwitcherToFrontmostApp = Defaults.Keys.limitSwitcherToFrontmostApp.defaultValue
                fullscreenAppBlacklist = Defaults.Keys.fullscreenAppBlacklist.defaultValue

                Defaults[.UserKeybind] = Defaults.Keys.UserKeybind.defaultValue
                Defaults[.windowSwitcherPlacementStrategy] = Defaults.Keys.windowSwitcherPlacementStrategy.defaultValue
                Defaults[.pinnedScreenIdentifier] = Defaults.Keys.pinnedScreenIdentifier.defaultValue
                Defaults[.enableShiftWindowSwitcherPlacement] = Defaults.Keys.enableShiftWindowSwitcherPlacement.defaultValue
                Defaults[.windowSwitcherHorizontalOffsetPercent] = Defaults.Keys.windowSwitcherHorizontalOffsetPercent.defaultValue
                Defaults[.windowSwitcherVerticalOffsetPercent] = Defaults.Keys.windowSwitcherVerticalOffsetPercent.defaultValue
                Defaults[.windowSwitcherAnchorToTop] = Defaults.Keys.windowSwitcherAnchorToTop.defaultValue

                // Reset gesture settings
                Defaults[.enableDockPreviewGestures] = Defaults.Keys.enableDockPreviewGestures.defaultValue
                Defaults[.dockSwipeTowardsDockAction] = Defaults.Keys.dockSwipeTowardsDockAction.defaultValue
                Defaults[.dockSwipeAwayFromDockAction] = Defaults.Keys.dockSwipeAwayFromDockAction.defaultValue
                Defaults[.enableWindowSwitcherGestures] = Defaults.Keys.enableWindowSwitcherGestures.defaultValue
                Defaults[.switcherSwipeUpAction] = Defaults.Keys.switcherSwipeUpAction.defaultValue
                Defaults[.switcherSwipeDownAction] = Defaults.Keys.switcherSwipeDownAction.defaultValue
                Defaults[.gestureSwipeThreshold] = Defaults.Keys.gestureSwipeThreshold.defaultValue
                Defaults[.middleClickAction] = Defaults.Keys.middleClickAction.defaultValue

                // Reset keyboard shortcuts
                Defaults[.cmdShortcut1Key] = Defaults.Keys.cmdShortcut1Key.defaultValue
                Defaults[.cmdShortcut1Action] = Defaults.Keys.cmdShortcut1Action.defaultValue
                Defaults[.cmdShortcut2Key] = Defaults.Keys.cmdShortcut2Key.defaultValue
                Defaults[.cmdShortcut2Action] = Defaults.Keys.cmdShortcut2Action.defaultValue
                Defaults[.cmdShortcut3Key] = Defaults.Keys.cmdShortcut3Key.defaultValue
                Defaults[.cmdShortcut3Action] = Defaults.Keys.cmdShortcut3Action.defaultValue

                // Reset alternate keybind
                Defaults[.alternateKeybindKey] = Defaults.Keys.alternateKeybindKey.defaultValue
                Defaults[.alternateKeybindMode] = Defaults.Keys.alternateKeybindMode.defaultValue

                Defaults[.showSpecialAppControls] = Defaults.Keys.showSpecialAppControls.defaultValue
                Defaults[.showBigControlsWhenNoValidWindows] = Defaults.Keys.showBigControlsWhenNoValidWindows.defaultValue
                Defaults[.useEmbeddedMediaControls] = Defaults.Keys.useEmbeddedMediaControls.defaultValue
                Defaults[.enablePinning] = Defaults.Keys.enablePinning.defaultValue
                Defaults[.filteredCalendarIdentifiers] = Defaults.Keys.filteredCalendarIdentifiers.defaultValue
                groupAppInstancesInDock = Defaults.Keys.groupAppInstancesInDock.defaultValue

                // Reset image preview settings
                disableImagePreview = Defaults.Keys.disableImagePreview.defaultValue

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

            // Extract app information in background
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

                    // Automatically add the app and close the sheet
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
