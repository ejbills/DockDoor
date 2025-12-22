import Defaults
import SwiftUI

struct GesturesAndKeybindsSettingsView: View {
    @Default(.enableDockPreviewGestures) var enableDockPreviewGestures
    @Default(.dockSwipeTowardsDockAction) var dockSwipeTowardsDockAction
    @Default(.dockSwipeAwayFromDockAction) var dockSwipeAwayFromDockAction
    @Default(.enableWindowSwitcherGestures) var enableWindowSwitcherGestures
    @Default(.switcherSwipeUpAction) var switcherSwipeUpAction
    @Default(.switcherSwipeDownAction) var switcherSwipeDownAction
    @Default(.gestureSwipeThreshold) var gestureSwipeThreshold
    @Default(.enableDockScrollGesture) var enableDockScrollGesture
    @Default(.dockIconMediaScrollBehavior) var dockIconMediaScrollBehavior
    @Default(.middleClickAction) var middleClickAction
    @Default(.aeroShakeAction) var aeroShakeAction
    @Default(.enableWindowSwitcher) var enableWindowSwitcher
    @Default(.fullscreenAppBlacklist) var fullscreenAppBlacklist
    @Default(.cmdShortcut1Key) var cmdShortcut1Key
    @Default(.cmdShortcut1Action) var cmdShortcut1Action
    @Default(.cmdShortcut2Key) var cmdShortcut2Key
    @Default(.cmdShortcut2Action) var cmdShortcut2Action
    @Default(.cmdShortcut3Key) var cmdShortcut3Key
    @Default(.cmdShortcut3Action) var cmdShortcut3Action
    @Default(.alternateKeybindKey) var alternateKeybindKey
    @Default(.alternateKeybindMode) var alternateKeybindMode
    @Default(.requireShiftTabToGoBack) var requireShiftTabToGoBack

    @StateObject private var keybindModel = KeybindModel()
    @State private var showingAddBlacklistAppSheet = false
    @State private var newBlacklistApp = ""
    @State private var capturingShortcutSlot: Int? = nil
    @State private var capturingAlternateKey = false
    @State private var keyMonitor: Any? = nil

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                dockScrollGestureSection
                dockPreviewGesturesSection
                windowSwitcherGesturesSection
                gestureSettingsSection
                mouseActionsSection
                cmdKeyShortcutsSection
                windowSwitcherKeybindSection
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
        .onAppear {
            keybindModel.modifierKey = Defaults[.UserKeybind].modifierFlags
            keybindModel.currentKeybind = Defaults[.UserKeybind]
        }
    }

    private var dockScrollGestureSection: some View {
        StyledGroupBox(label: "Dock Icon Scroll Gesture") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $enableDockScrollGesture) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.accentColor)
                        Text("Enable scroll gestures on dock icons")
                    }
                }

                if enableDockScrollGesture {
                    Text("Scroll up on a dock icon to bring the app to front, scroll down to hide all its windows.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    Divider()

                    Picker("Music/Spotify behavior:", selection: $dockIconMediaScrollBehavior) {
                        ForEach(DockIconMediaScrollBehavior.allCases, id: \.self) { behavior in
                            Text(behavior.localizedName).tag(behavior)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var dockPreviewGesturesSection: some View {
        StyledGroupBox(label: "Dock Preview Gestures") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $enableDockPreviewGestures) {
                    HStack(spacing: 8) {
                        Image(systemName: "dock.rectangle")
                            .foregroundColor(.accentColor)
                        Text("Enable gestures on dock window previews")
                    }
                }

                if enableDockPreviewGestures {
                    Text("Swipe on window previews in the dock popup. Direction is relative to dock position — swipe towards the dock (e.g., down when dock is at bottom, left when dock is on left).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    Divider()

                    gestureDirectionRow(
                        direction: "Towards Dock",
                        icon: "arrow.down.to.line",
                        description: "Swipe toward the dock edge",
                        action: $dockSwipeTowardsDockAction
                    )

                    gestureDirectionRow(
                        direction: "Away from Dock",
                        icon: "arrow.up.to.line",
                        description: "Swipe away from the dock edge",
                        action: $dockSwipeAwayFromDockAction
                    )

                    Divider()

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.point.up.left.and.text")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                Text("Aero Shake")
                            }
                            Text("Shake a window preview rapidly")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 26)
                        }
                        .frame(minWidth: 140, alignment: .leading)

                        Picker("", selection: $aeroShakeAction) {
                            ForEach(AeroShakeAction.allCases, id: \.self) { action in
                                Text(action.localizedName).tag(action)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    Button("Reset to Defaults") {
                        dockSwipeTowardsDockAction = Defaults.Keys.dockSwipeTowardsDockAction.defaultValue
                        dockSwipeAwayFromDockAction = Defaults.Keys.dockSwipeAwayFromDockAction.defaultValue
                        aeroShakeAction = Defaults.Keys.aeroShakeAction.defaultValue
                    }
                    .buttonStyle(AccentButtonStyle(small: true))
                    .padding(.top, 4)
                }
            }
        }
    }

    private var windowSwitcherGesturesSection: some View {
        StyledGroupBox(label: "Window Switcher Gestures") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $enableWindowSwitcherGestures) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.3.group")
                            .foregroundColor(.accentColor)
                        Text("Enable gestures in window switcher")
                    }
                }

                if enableWindowSwitcherGestures {
                    Text("Swipe up or down on window previews in the keyboard-activated window switcher. Only vertical swipes are recognized, unless in compact mode.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    Divider()

                    gestureDirectionRow(
                        direction: "Swipe Up",
                        icon: "arrow.up",
                        description: nil,
                        action: $switcherSwipeUpAction
                    )

                    gestureDirectionRow(
                        direction: "Swipe Down",
                        icon: "arrow.down",
                        description: nil,
                        action: $switcherSwipeDownAction
                    )

                    Button("Reset to Defaults") {
                        switcherSwipeUpAction = Defaults.Keys.switcherSwipeUpAction.defaultValue
                        switcherSwipeDownAction = Defaults.Keys.switcherSwipeDownAction.defaultValue
                    }
                    .buttonStyle(AccentButtonStyle(small: true))
                    .padding(.top, 4)
                }
            }
        }
    }

    private var gestureSettingsSection: some View {
        StyledGroupBox(label: "Gesture Settings") {
            VStack(alignment: .leading, spacing: 4) {
                let thresholdBinding = Binding<Double>(
                    get: { Double(gestureSwipeThreshold) },
                    set: { gestureSwipeThreshold = CGFloat($0) }
                )
                sliderSetting(
                    title: "Gesture Sensitivity",
                    value: thresholdBinding,
                    range: 20 ... 100,
                    step: 10,
                    unit: "px",
                    formatter: {
                        let f = NumberFormatter()
                        f.minimumFractionDigits = 0
                        f.maximumFractionDigits = 0
                        return f
                    }()
                )
                Text("Lower values make gestures more sensitive. Higher values require longer swipes. Applies to both dock previews and window switcher.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func gestureDirectionRow(direction: String, icon: String, description: String?, action: Binding<WindowAction>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(direction)
                }
                if let description {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 26)
                }
            }
            .frame(minWidth: 140, alignment: .leading)

            Picker("", selection: action) {
                ForEach(WindowAction.gestureActions, id: \.self) { windowAction in
                    HStack(spacing: 6) {
                        Image(systemName: windowAction.iconName)
                        Text(windowAction.localizedName)
                    }
                    .tag(windowAction)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private var mouseActionsSection: some View {
        StyledGroupBox(label: "Mouse Actions") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "computermouse.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text("Middle Click")
                            .frame(width: 80, alignment: .leading)
                    }

                    Picker("", selection: $middleClickAction) {
                        ForEach(WindowAction.gestureActions, id: \.self) { windowAction in
                            HStack(spacing: 6) {
                                Image(systemName: windowAction.iconName)
                                Text(windowAction.localizedName)
                            }
                            .tag(windowAction)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                Text("Action performed when middle-clicking on a window preview.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var cmdKeyShortcutsSection: some View {
        StyledGroupBox(label: "Window Preview Keyboard Shortcuts") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cmd+key shortcuts for quick actions on the selected window preview. These work in both the window switcher and Cmd+Tab enhancement mode.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                cmdShortcutRow(
                    slot: 1,
                    keyBinding: $cmdShortcut1Key,
                    actionBinding: $cmdShortcut1Action
                )

                cmdShortcutRow(
                    slot: 2,
                    keyBinding: $cmdShortcut2Key,
                    actionBinding: $cmdShortcut2Action
                )

                cmdShortcutRow(
                    slot: 3,
                    keyBinding: $cmdShortcut3Key,
                    actionBinding: $cmdShortcut3Action
                )

                Button("Reset to Defaults") {
                    cmdShortcut1Key = Defaults.Keys.cmdShortcut1Key.defaultValue
                    cmdShortcut1Action = Defaults.Keys.cmdShortcut1Action.defaultValue
                    cmdShortcut2Key = Defaults.Keys.cmdShortcut2Key.defaultValue
                    cmdShortcut2Action = Defaults.Keys.cmdShortcut2Action.defaultValue
                    cmdShortcut3Key = Defaults.Keys.cmdShortcut3Key.defaultValue
                    cmdShortcut3Action = Defaults.Keys.cmdShortcut3Action.defaultValue
                }
                .buttonStyle(AccentButtonStyle(small: true))
                .padding(.top, 4)
            }
        }
    }

    private func cmdShortcutRow(slot: Int, keyBinding: Binding<UInt16>, actionBinding: Binding<WindowAction>) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("⌘")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                if capturingShortcutSlot == slot {
                    Text("Press a key…")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                        .frame(minWidth: 50)
                } else {
                    Button(action: {
                        capturingShortcutSlot = slot
                        startKeyCapture(keyBinding: keyBinding)
                    }) {
                        Text(KeyboardLabel.localizedKey(for: keyBinding.wrappedValue))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minWidth: 80, alignment: .leading)

            Picker("", selection: actionBinding) {
                ForEach(WindowAction.gestureActions, id: \.self) { windowAction in
                    HStack(spacing: 6) {
                        Image(systemName: windowAction.iconName)
                        Text(windowAction.localizedName)
                    }
                    .tag(windowAction)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private func startKeyCapture(keyBinding: Binding<UInt16>) {
        // Remove any existing monitor
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            defer {
                capturingShortcutSlot = nil
                if let monitor = keyMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyMonitor = nil
                }
            }

            // Escape cancels
            if event.keyCode == 53 { return nil }

            // Update the binding directly
            keyBinding.wrappedValue = event.keyCode
            return nil
        }
    }

    private var windowSwitcherKeybindSection: some View {
        StyledGroupBox(label: "Window Switcher Shortcuts") {
            VStack(alignment: .leading, spacing: 12) {
                if !enableWindowSwitcher {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Window Switcher is disabled. Enable it in General settings to use keyboard shortcuts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(8)
                }

                keyboardShortcutSection()
                    .disabled(!enableWindowSwitcher)
                    .opacity(enableWindowSwitcher ? 1.0 : 0.5)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $requireShiftTabToGoBack) {
                        Text("Require Shift+Tab to go back in Switcher")
                    }
                    Text("When enabled, pressing Shift alone won't go back. Use Shift+Tab (or modifier+Shift+Tab when release-to-select is on) to navigate backward.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
                .disabled(!enableWindowSwitcher)
                .opacity(enableWindowSwitcher ? 1.0 : 0.5)

                Divider()

                alternateShortcutsSection
                    .disabled(!enableWindowSwitcher)
                    .opacity(enableWindowSwitcher ? 1.0 : 0.5)

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
    }

    private var alternateShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alternate Shortcut").font(.headline)
            Text("An additional trigger key using the same modifier, invoking the switcher with a different filter mode.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                // Modifier display (from primary keybind)
                Text(modifierConverter.toString(keybindModel.modifierKey))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                Text("+")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                // Key capture
                if capturingAlternateKey {
                    Text("Press a key…")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                        .frame(minWidth: 50)
                } else {
                    Button(action: {
                        startAlternateKeyCapture()
                    }) {
                        Text(alternateKeybindKey == 0 ? "Not set" : KeyboardLabel.localizedKey(for: alternateKeybindKey))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(alternateKeybindKey == 0 ? Color.secondary.opacity(0.1) : Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }

                if alternateKeybindKey != 0 {
                    Button("Clear") {
                        alternateKeybindKey = 0
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Picker("Mode", selection: $alternateKeybindMode) {
                    ForEach(SwitcherInvocationMode.allCases) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 200)
            }
        }
    }

    private func startAlternateKeyCapture() {
        // Remove any existing monitor
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }

        capturingAlternateKey = true

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            defer {
                capturingAlternateKey = false
                if let monitor = keyMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyMonitor = nil
                }
            }

            // Escape cancels
            if event.keyCode == 53 { return nil }

            // Update the binding directly
            alternateKeybindKey = event.keyCode
            return nil
        }
    }

    private func keyboardShortcutSection() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Current shortcut summary
            if let keybind = keybindModel.currentKeybind, keybind.keyCode != 0 {
                HStack(spacing: 8) {
                    KeyCapView(text: modifierConverter.toString(keybind.modifierFlags), symbol: nil)
                    Text("+").foregroundColor(.secondary)
                    KeyCapView(text: KeyboardLabel.localizedKey(for: keybind.keyCode), symbol: nil)
                }
            } else {
                Text("No shortcut set").foregroundColor(.secondary)
            }

            // Controls: initializer modifier + capture button
            HStack(spacing: 12) {
                Picker("Initializer", selection: $keybindModel.modifierKey) {
                    Text("Control ⌃").tag(Defaults[.Int64maskControl])
                    Text("Option ⌥").tag(Defaults[.Int64maskAlternate])
                    Text("Command ⌘").tag(Defaults[.Int64maskCommand])
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .onChange(of: keybindModel.modifierKey) { newValue in
                    if let currentKeybind = keybindModel.currentKeybind, currentKeybind.keyCode != 0 {
                        let updatedKeybind = UserKeyBind(keyCode: currentKeybind.keyCode, modifierFlags: newValue)
                        Defaults[.UserKeybind] = updatedKeybind
                        keybindModel.currentKeybind = updatedKeybind
                    }
                }

                Button(action: { keybindModel.isRecording.toggle() }) {
                    HStack {
                        Image(systemName: keybindModel.isRecording ? "keyboard.fill" : "record.circle")
                        Text(keybindModel.isRecording ? "Press shortcut…" : "Change…")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(keybindModel.isRecording)

                Button("Reset") {
                    let def = UserKeyBind(keyCode: 48, modifierFlags: Defaults[.Int64maskAlternate])
                    Defaults[.UserKeybind] = def
                    keybindModel.currentKeybind = def
                    keybindModel.modifierKey = def.modifierFlags
                }
                .buttonStyle(.bordered)
            }

            Text("Either left or right Command, Option, or Control keys work. You can also hold the modifier while pressing the trigger to capture both.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
                .disabled(!enableWindowSwitcher)

                Spacer()

                if !fullscreenAppBlacklist.isEmpty {
                    DangerButton(action: {
                        fullscreenAppBlacklist.removeAll()
                    }) {
                        Text("Remove All")
                    }
                    .disabled(!enableWindowSwitcher)
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
}
