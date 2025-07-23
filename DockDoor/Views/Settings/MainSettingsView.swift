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
                inactivityTimeout: Defaults.Keys.inactivityTimeout.defaultValue,
                tapEquivalentInterval: Defaults.Keys.tapEquivalentInterval.defaultValue,
                lateralMovement: Defaults.Keys.lateralMovement.defaultValue,
                preventDockHide: Defaults.Keys.preventDockHide.defaultValue
            )
        case .snappy:
            PerformanceProfileSettingsValues(hoverWindowOpenDelay: CoreDockGetAutoHideEnabled() ? 0.1 : 0, fadeOutDuration: 0.15, inactivityTimeout: 0.5, tapEquivalentInterval: 0.5, lateralMovement: false, preventDockHide: false)
        case .relaxed:
            PerformanceProfileSettingsValues(hoverWindowOpenDelay: 0.25, fadeOutDuration: 0.5, inactivityTimeout: 2.5, tapEquivalentInterval: 1.5, lateralMovement: true, preventDockHide: true)
        }
    }
}

struct PerformanceProfileSettingsValues {
    let hoverWindowOpenDelay: CGFloat
    let fadeOutDuration: CGFloat
    let inactivityTimeout: CGFloat
    let tapEquivalentInterval: CGFloat
    let lateralMovement: Bool
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
    @Default(.includeHiddenWindowsInSwitcher) var includeHiddenWindowsInSwitcher
    @Default(.useClassicWindowOrdering) var useClassicWindowOrdering
    @Default(.limitSwitcherToFrontmostApp) var limitSwitcherToFrontmostApp
    @Default(.fullscreenAppBlacklist) var fullscreenAppBlacklist

    @State private var selectedPerformanceProfile: SettingsProfile = .default
    @State private var selectedPreviewQualityProfile: PreviewQualityProfile = .standard
    @State private var showAdvancedSettings: Bool = false
    @StateObject private var keybindModel = KeybindModel()
    @State private var showingAddBlacklistAppSheet = false
    @State private var newBlacklistApp = ""
    @Default(.windowSwitcherPlacementStrategy) var placementStrategy
    @Default(.pinnedScreenIdentifier) var pinnedScreenIdentifier

    @Default(.hoverWindowOpenDelay) var hoverWindowOpenDelay
    @Default(.fadeOutDuration) var fadeOutDuration
    @Default(.inactivityTimeout) var inactivityTimeout
    @Default(.tapEquivalentInterval) var tapEquivalentInterval
    @Default(.lateralMovement) var lateralMovement
    @Default(.preventDockHide) var preventDockHide
    @Default(.preventSwitcherHide) var preventSwitcherHide
    @Default(.ignoreAppsWithSingleWindow) var ignoreAppsWithSingleWindow
    @Default(.screenCaptureCacheLifespan) var screenCaptureCacheLifespan
    @Default(.windowPreviewImageScale) var windowPreviewImageScale
    @Default(.bufferFromDock) var bufferFromDock
    @Default(.sortWindowsByDate) var sortWindowsByDate
    @Default(.shouldHideOnDockItemClick) var shouldHideOnDockItemClick
    @Default(.dockClickAction) var dockClickAction
    @Default(.previewHoverAction) var previewHoverAction
    @Default(.aeroShakeAction) var aeroShakeAction
    @Default(.showSpecialAppControls) var showSpecialAppControls
    @Default(.useEmbeddedMediaControls) var useEmbeddedMediaControls
    @Default(.showAnimations) var showAnimations
    @Default(.raisedWindowLevel) var raisedWindowLevel
    @Default(.enablePinning) var enablePinning
    @Default(.showBigControlsWhenNoValidWindows) var showBigControlsWhenNoValidWindows

    private let advancedSettingsSectionID = "advancedSettingsSection"
    private let windowSwitcherAdvancedSettingsID = "windowSwitcherAdvancedSettings"

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
                        if enableWindowSwitcher {
                            windowSwitcherAdvancedSection.id(windowSwitcherAdvancedSettingsID)
                        }
                    }
                }
                .background(
                    ShortcutCaptureView(
                        currentKeybind: $keybindModel.currentKeybind,
                        isRecording: $keybindModel.isRecording,
                        modifierKey: $keybindModel.modifierKey
                    )
                    .allowsHitTesting(false)
                    .frame(width: 0, height: 0)
                )
            }
        }
        .onChange(of: enablePinning) { isEnabled in
            if !isEnabled {
                SharedPreviewWindowCoordinator.activeInstance?.unpinAll()
            }
        }
        .onAppear {
            if doesCurrentSettingsMatchPerformanceProfile(.snappy) { selectedPerformanceProfile = .snappy }
            else if doesCurrentSettingsMatchPerformanceProfile(.relaxed) { selectedPerformanceProfile = .relaxed }
            else if doesCurrentSettingsMatchPerformanceProfile(.default) { selectedPerformanceProfile = .default }

            if doesCurrentSettingsMatchPreviewQualityProfile(.detailed) { selectedPreviewQualityProfile = .detailed }
            else if doesCurrentSettingsMatchPreviewQualityProfile(.lightweight) { selectedPreviewQualityProfile = .lightweight }
            else if doesCurrentSettingsMatchPreviewQualityProfile(.standard) { selectedPreviewQualityProfile = .standard }

            keybindModel.modifierKey = Defaults[.UserKeybind].modifierFlags
            keybindModel.currentKeybind = Defaults[.UserKeybind]
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

                Text("Thanks for supporting DockDoor! 💖")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
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

                Divider().padding(.vertical, 2)

                Toggle(isOn: $enableWindowSwitcher) { Text("Enable Window Switcher") }
                    .onChange(of: enableWindowSwitcher) { _ in askUserToRestartApplication() }

                Text("The Window Switcher (often Alt/Cmd-Tab) lets you quickly cycle between open app windows with a keyboard shortcut.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if enableWindowSwitcher {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $includeHiddenWindowsInSwitcher) { Text("Include hidden/minimized windows in Switcher") }
                        Toggle(isOn: Binding(
                            get: { !preventSwitcherHide },
                            set: { preventSwitcherHide = !$0 }
                        )) { Text("Release initializer key to select window in Switcher") }
                        Toggle(isOn: $useClassicWindowOrdering) { Text("Use Windows-style window ordering in Switcher") }
                        Text("Shows last active window first, instead of current window.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)

                        Toggle(isOn: $limitSwitcherToFrontmostApp) { Text("Limit Window Switcher to active app only") }
                        Text("Only show windows from the currently active/frontmost application.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                    .padding(.leading, 20)
                    .padding(.top, 4)
                }

                Divider().padding(.vertical, 2)

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
                    sliderSetting(title: "Preview Window Fade Out Duration", value: $fadeOutDuration, range: 0 ... 2, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter)
                    sliderSetting(title: "Preview Window Inactivity Timer", value: $inactivityTimeout, range: 0 ... 3, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter)
                    Toggle(isOn: $lateralMovement) { Text("Keep previews visible during lateral movement") }
                    Toggle(isOn: $preventDockHide) { Text("Prevent dock from hiding during previews") }
                    Toggle(isOn: $raisedWindowLevel) { Text("Show preview above app labels").onChange(of: raisedWindowLevel) { _ in askUserToRestartApplication() }}
                }
            }
            StyledGroupBox(label: "Preview Appearance & Quality") {
                VStack(alignment: .leading, spacing: 10) {
                    sliderSetting(title: "Window Image Cache Lifespan", value: $screenCaptureCacheLifespan, range: 0 ... 60, step: 10, unit: "seconds")
                    sliderSetting(title: "Window Image Resolution Scale (1=Best)", value: $windowPreviewImageScale, range: 1 ... 4, step: 1, unit: "")
                    Toggle(isOn: $sortWindowsByDate) { Text("Sort Window Previews by Date (if multiple)") }
                }
            }
            StyledGroupBox(label: "Interaction & Behavior (Dock Previews)") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Dock Preview Hover Action", selection: $previewHoverAction) { ForEach(PreviewHoverAction.allCases, id: \.self) { Text($0.localizedName).tag($0) } }.pickerStyle(MenuPickerStyle())
                    sliderSetting(title: "Preview Hover Action Delay", value: $tapEquivalentInterval, range: 0 ... 2, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter).disabled(previewHoverAction == .none)
                    Picker("Dock Preview Aero Shake Action", selection: $aeroShakeAction) { ForEach(AeroShakeAction.allCases, id: \.self) { Text($0.localizedName).tag($0) } }.pickerStyle(MenuPickerStyle())
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
                    Toggle(isOn: $showSpecialAppControls) { Text("Show media/calendar controls on Dock hover") }
                    Text("For supported apps (Music, Spotify, Calendar), show interactive controls instead of window previews when hovering their Dock icons.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                    if showSpecialAppControls {
                        Toggle(isOn: $useEmbeddedMediaControls) { Text("Embed controls with window previews (if previews shown)") }
                            .padding(.leading, 20)
                        Text("If enabled, controls integrate with previews when possible.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 40)

                        Toggle(isOn: $showBigControlsWhenNoValidWindows) { Text("Show big controls when no valid windows") }
                            .padding(.leading, 20)
                            .disabled(!useEmbeddedMediaControls)
                        Text(useEmbeddedMediaControls ?
                            "When embedded mode is enabled, show big controls instead of embedded ones if all windows are minimized/hidden or there are no windows." :
                            "This setting only applies when \"Embed controls with window previews\" is enabled above.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 40)
                            .opacity(useEmbeddedMediaControls ? 1.0 : 0.6)

                        Toggle(isOn: $enablePinning) { Text("Enable Pinning") }
                            .padding(.leading, 20)
                        Text("Allow special app controls to be pinned to the screen via right-click menu.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 40)
                    }

                    sliderSetting(title: "Window Buffer from Dock (pixels)", value: $bufferFromDock, range: -100 ... 100, step: 5, unit: "px", formatter: { let f = NumberFormatter(); f.allowsFloats = false; f.minimumIntegerDigits = 1; f.maximumFractionDigits = 0; return f }())
                }
            }
        }.padding(.top, 5)
    }

    private var windowSwitcherAdvancedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            StyledGroupBox(label: "Window Switcher Customization") {
                VStack(alignment: .leading, spacing: 10) {
                    keyboardShortcutSection()
                    Divider()
                    Text("Window Switcher Placement").font(.headline)
                    Picker("Placement Strategy", selection: $placementStrategy) { ForEach(WindowSwitcherPlacementStrategy.allCases, id: \.self) { Text($0.localizedName).tag($0) } }
                        .labelsHidden()
                        .onChange(of: placementStrategy) { newStrategy in if newStrategy == .pinnedToScreen, pinnedScreenIdentifier.isEmpty { pinnedScreenIdentifier = NSScreen.main?.uniqueIdentifier() ?? "" } }
                    if placementStrategy == .pinnedToScreen {
                        VStack(alignment: .leading, spacing: 4) {
                            Picker("Pin to Screen", selection: $pinnedScreenIdentifier) {
                                ForEach(NSScreen.screens, id: \.self) { screen in Text(screenDisplayName(screen)).tag(screen.uniqueIdentifier()) }
                                if !pinnedScreenIdentifier.isEmpty, !NSScreen.screens.contains(where: { $0.uniqueIdentifier() == pinnedScreenIdentifier }) { Text("Disconnected Display").tag(pinnedScreenIdentifier) }
                            }.labelsHidden()
                            if !pinnedScreenIdentifier.isEmpty, !NSScreen.screens.contains(where: { $0.uniqueIdentifier() == pinnedScreenIdentifier }) { Text("This display is currently disconnected. The window switcher will appear on the main display until the selected display is reconnected.", comment: "Message shown when a pinned display is disconnected").font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fullscreen App Blacklist").font(.headline)
                        Text("Apps in this list will not respond to window switcher shortcuts when in fullscreen mode.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        fullscreenAppBlacklistView
                    }
                }
            }
        }.padding(.top, 5)
            .onAppear { keybindModel.modifierKey = Defaults[.UserKeybind].modifierFlags; keybindModel.currentKeybind = Defaults[.UserKeybind] }
    }

    private var fullscreenAppBlacklistView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if !fullscreenAppBlacklist.isEmpty {
                        ForEach(fullscreenAppBlacklist, id: \.self) { appName in
                            HStack {
                                Text(appName)
                                    .foregroundColor(.primary)

                                Spacer()

                                Button(action: {
                                    fullscreenAppBlacklist.removeAll { $0 == appName }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)

                            if appName != fullscreenAppBlacklist.last {
                                Divider()
                            }
                        }
                    } else {
                        Text("No apps in blacklist")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(8)
            }
            .frame(maxHeight: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )

            HStack {
                Button(action: { showingAddBlacklistAppSheet.toggle() }) {
                    Text("Add App")
                }
                .buttonStyle(AccentButtonStyle())

                Spacer()

                if !fullscreenAppBlacklist.isEmpty {
                    DangerButton(action: {
                        fullscreenAppBlacklist.removeAll()
                    }) {
                        Text("Remove All")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddBlacklistAppSheet) {
            AddBlacklistAppSheet(
                isPresented: $showingAddBlacklistAppSheet,
                appNameToAdd: $newBlacklistApp,
                onAdd: { appName in
                    if !appName.isEmpty, !fullscreenAppBlacklist.contains(where: { $0.caseInsensitiveCompare(appName) == .orderedSame }) {
                        fullscreenAppBlacklist.append(appName)
                    }
                }
            )
        }
    }

    private func modifierSymbol(_ modifier: Int) -> String {
        switch modifier {
        case Defaults[.Int64maskControl]: "control"
        case Defaults[.Int64maskAlternate]: "option"
        case Defaults[.Int64maskCommand]: "command"
        default: ""
        }
    }

    private func keyboardShortcutSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcut").font(.headline)
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Initialization Key").font(.subheadline).foregroundColor(.secondary)
                    Picker("", selection: $keybindModel.modifierKey) {
                        Text("Control (⌃)").tag(Defaults[.Int64maskControl]); Text("Option (⌥)").tag(Defaults[.Int64maskAlternate]); Text("Command (⌘)").tag(Defaults[.Int64maskCommand])
                    }.pickerStyle(SegmentedPickerStyle()).frame(maxWidth: 250)
                        .onChange(of: keybindModel.modifierKey) { newValue in if let currentKeybind = keybindModel.currentKeybind, currentKeybind.keyCode != 0 { let updatedKeybind = UserKeyBind(keyCode: currentKeybind.keyCode, modifierFlags: newValue); Defaults[.UserKeybind] = updatedKeybind; keybindModel.currentKeybind = updatedKeybind } }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trigger Key").font(.subheadline).foregroundColor(.secondary)
                    Button(action: { keybindModel.isRecording.toggle() }) { HStack { Image(systemName: keybindModel.isRecording ? "keyboard.fill" : "record.circle"); Text(keybindModel.isRecording ? "Press any key..." : "Set Trigger Key") }.frame(maxWidth: 150) }
                        .buttonStyle(.borderedProminent).disabled(keybindModel.isRecording)
                }
            }
            if let keybind = keybindModel.currentKeybind, keybind.keyCode != 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Shortcut").font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        KeyCapView(text: modifierConverter.toString(keybind.modifierFlags), symbol: modifierSymbol(keybind.modifierFlags))
                        Text("+").foregroundColor(.secondary)
                        KeyCapView(text: KeyCodeConverter.toString(keybind.keyCode), symbol: nil)
                    }
                }.padding(.top, 4)
            }
            StyledGroupBox(label: "Instructions") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to Set Up").font(.subheadline).bold()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top, spacing: 8) { Text("1."); Text("Select an initialization key (e.g. Command ⌘)") }
                        HStack(alignment: .top, spacing: 8) { Text("2."); Text("Click \"Set Trigger Key\"") }
                        HStack(alignment: .top, spacing: 8) { Text("3."); Text("Press ONLY the trigger key (e.g. just Tab)") }
                        HStack(alignment: .top, spacing: 8) { Text("4."); Text("Your shortcut will be set (e.g. ⌘ + Tab)") }
                    }
                }
            }.padding(.top, 8)
        }
    }

    private func screenDisplayName(_ screen: NSScreen) -> String {
        let isMain = screen == NSScreen.main
        var name = screen.localizedName
        if name.isEmpty {
            if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID { name = String(format: NSLocalizedString("Display %u", comment: "Generic display name with CGDirectDisplayID"), displayID) }
            else { name = String(localized: "Unknown Display") }
        }
        return name + (isMain ? " (Main)" : "")
    }

    private func applyPerformanceProfileSettings(_ profile: SettingsProfile) {
        let settings = profile.settings
        hoverWindowOpenDelay = settings.hoverWindowOpenDelay
        fadeOutDuration = settings.fadeOutDuration
        inactivityTimeout = settings.inactivityTimeout
        tapEquivalentInterval = settings.tapEquivalentInterval
        lateralMovement = settings.lateralMovement
        preventDockHide = settings.preventDockHide
    }

    private func doesCurrentSettingsMatchPerformanceProfile(_ profile: SettingsProfile) -> Bool {
        let settings = profile.settings
        return hoverWindowOpenDelay == settings.hoverWindowOpenDelay &&
            fadeOutDuration == settings.fadeOutDuration &&
            inactivityTimeout == settings.inactivityTimeout &&
            tapEquivalentInterval == settings.tapEquivalentInterval &&
            lateralMovement == settings.lateralMovement &&
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
                hoverWindowOpenDelay = perfDefault.hoverWindowOpenDelay; fadeOutDuration = perfDefault.fadeOutDuration; inactivityTimeout = perfDefault.inactivityTimeout; tapEquivalentInterval = perfDefault.tapEquivalentInterval; lateralMovement = perfDefault.lateralMovement; preventDockHide = perfDefault.preventDockHide
                let qualityDefault = PreviewQualityProfile.standard.settings
                screenCaptureCacheLifespan = qualityDefault.screenCaptureCacheLifespan; windowPreviewImageScale = qualityDefault.windowPreviewImageScale
                bufferFromDock = Defaults.Keys.bufferFromDock.defaultValue; sortWindowsByDate = Defaults.Keys.sortWindowsByDate.defaultValue; shouldHideOnDockItemClick = Defaults.Keys.shouldHideOnDockItemClick.defaultValue; dockClickAction = Defaults.Keys.dockClickAction.defaultValue; previewHoverAction = Defaults.Keys.previewHoverAction.defaultValue; aeroShakeAction = Defaults.Keys.aeroShakeAction.defaultValue

                showMenuBarIcon = Defaults.Keys.showMenuBarIcon.defaultValue
                enableWindowSwitcher = Defaults.Keys.enableWindowSwitcher.defaultValue
                includeHiddenWindowsInSwitcher = Defaults.Keys.includeHiddenWindowsInSwitcher.defaultValue
                useClassicWindowOrdering = Defaults.Keys.useClassicWindowOrdering.defaultValue
                limitSwitcherToFrontmostApp = Defaults.Keys.limitSwitcherToFrontmostApp.defaultValue
                fullscreenAppBlacklist = Defaults.Keys.fullscreenAppBlacklist.defaultValue

                Defaults[.UserKeybind] = Defaults.Keys.UserKeybind.defaultValue
                keybindModel.currentKeybind = Defaults[.UserKeybind]
                keybindModel.modifierKey = Defaults[.UserKeybind].modifierFlags

                showSpecialAppControls = Defaults.Keys.showSpecialAppControls.defaultValue
                showBigControlsWhenNoValidWindows = Defaults.Keys.showBigControlsWhenNoValidWindows.defaultValue
                placementStrategy = Defaults.Keys.windowSwitcherPlacementStrategy.defaultValue
                pinnedScreenIdentifier = Defaults.Keys.pinnedScreenIdentifier.defaultValue
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
