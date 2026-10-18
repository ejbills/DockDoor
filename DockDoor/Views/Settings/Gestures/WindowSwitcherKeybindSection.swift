import Carbon.HIToolbox
import Defaults
import SwiftUI

struct WindowSwitcherKeybindSection: View {
    @Default(.enableWindowSwitcherSearch) var enableWindowSwitcherSearch
    @Default(.searchTriggerKey) var searchTriggerKey
    @Default(.fullscreenAppBlacklist) var fullscreenAppBlacklist
    @Default(.alternateKeybindKey) var alternateKeybindKey
    @Default(.alternateKeybindMode) var alternateKeybindMode
    @Default(.alternateKeybindModifierFlags) var alternateKeybindModifierFlags
    @Default(.requireShiftTabToGoBack) var requireShiftTabToGoBack
    @Default(.switcherBackwardKeyCode) var switcherBackwardKeyCode
    @Default(.windowSwitcherSelectionKeyCode) var selectionKeyCode
    @Default(.enableVimMotions) var enableVimMotions
    @Default(.passArrowsThroughToSystem) var passArrowsThroughToSystem

    @StateObject private var keybindModel = KeybindModel()
    @State private var showingAddBlacklistAppSheet = false
    @State private var newBlacklistApp = ""

    var body: some View {
        SettingsSection("Window switcher shortcuts") {
            shortcutRow
                .settingsSearchTarget("gestures.switcherKeybind")
                .settingsAnnotation("Either left or right Command, Option, or Control keys work. You can also hold the modifier while pressing the trigger to capture both.")

            LabeledContent("Backward Key") {
                HStack(spacing: 8) {
                    KeyCaptureButton(keyCode: $switcherBackwardKeyCode, captureModifiers: true)
                    SettingsResetButton(isModified: switcherBackwardKeyCode != 56) { switcherBackwardKeyCode = 56 }
                }
            }
            .settingsSearchTarget("gestures.backwardKey")
            .settingsAnnotation("The key used to navigate backward in the window switcher.")

            Toggle(isOn: $requireShiftTabToGoBack) {
                Text("Require \(KeyboardLabel.localizedKey(for: switcherBackwardKeyCode))+Tab to go back in Switcher")
            }
            .settingsSearchTarget("gestures.requireShiftTab")
            .settingsAnnotation("When enabled, pressing the backward key alone won't go back. Use it with Tab to navigate backward.")

            LabeledContent("Selection Key") {
                HStack(spacing: 8) {
                    KeyCaptureButton(keyCode: $selectionKeyCode)
                    SettingsResetButton(isModified: selectionKeyCode != UInt16(kVK_Return)) { selectionKeyCode = UInt16(kVK_Return) }
                }
            }
            .settingsSearchTarget("gestures.selectionKey")
            .settingsAnnotation("The key used to select and bring to front the highlighted window in the switcher.")

            if enableWindowSwitcherSearch {
                LabeledContent("Search Trigger Key") {
                    HStack(spacing: 6) {
                        Text(verbatim: "\(modifierConverter.toString(keybindModel.modifierKey)) +")
                            .foregroundStyle(.secondary)
                        KeyCaptureButton(keyCode: $searchTriggerKey)
                    }
                }
                .settingsSearchTarget("gestures.searchTriggerKey")
                .settingsAnnotation("The key that activates search while the window switcher is open.")
            }
        }
        .onAppear {
            keybindModel.modifierKey = Defaults[.UserKeybind].modifierFlags
            keybindModel.currentKeybind = Defaults[.UserKeybind]
        }

        SettingsSection("Alternate shortcut") {
            LabeledContent("Alternate Shortcut") {
                HStack(spacing: 6) {
                    Picker("Modifier", selection: $alternateKeybindModifierFlags) {
                        Text("Same as main (\(modifierConverter.toString(keybindModel.modifierKey)))").tag(0)
                        Text("Control ⌃").tag(Defaults[.Int64maskControl])
                        Text("Option ⌥").tag(Defaults[.Int64maskAlternate])
                        Text("Command ⌘").tag(Defaults[.Int64maskCommand])
                    }
                    .labelsHidden()
                    .fixedSize()
                    Text(verbatim: "+")
                        .foregroundStyle(.secondary)
                    KeyCaptureButton(keyCode: $alternateKeybindKey, emptyLabel: "Not set", allowsEscape: true)
                    SettingsResetButton(isModified: alternateKeybindKey != 0) { alternateKeybindKey = 0 }
                }
            }
            .settingsSearchTarget("gestures.alternateShortcut")
            .settingsAnnotation("An additional trigger key, with its own modifier if desired, invoking the switcher with a different filter mode.")

            if alternateKeybindKey != 0 {
                Picker("Mode", selection: $alternateKeybindMode) {
                    ForEach(SwitcherInvocationMode.allCases) { mode in
                        Text(mode.localizedName).tag(mode)
                    }
                }
            }
        }

        SettingsSection("Navigation") {
            Toggle(isOn: $enableVimMotions) {
                Text("Enable Vim Motions")
            }
            .settingsSearchTarget("gestures.vimMotions")
            .settingsAnnotation("Use H/J/K/L keys to navigate left/down/up/right in the window switcher. Disabled while search is focused.")

            Toggle(isOn: $passArrowsThroughToSystem) {
                Text("Pass Arrow Keys Through to System")
            }
            .settingsSearchTarget("gestures.arrowPassthrough")
            .settingsAnnotation("When enabled, Ctrl+Arrow keys will be passed through to the system instead of navigating the switcher. Useful for Spaces switching.")
        }

        SettingsSection("Fullscreen app blacklist") {
            fullscreenAppBlacklistView
                .settingsSearchTarget("gestures.fullscreenBlacklist")
                .settingsAnnotation("Apps in this list will not respond to window switcher shortcuts when in fullscreen mode.")
        }
    }

    // MARK: - Shortcut

    private var shortcutRow: some View {
        LabeledContent("Initializer") {
            HStack(spacing: 6) {
                Picker("Initializer", selection: $keybindModel.modifierKey) {
                    Text("Control ⌃").tag(Defaults[.Int64maskControl])
                    Text("Option ⌥").tag(Defaults[.Int64maskAlternate])
                    Text("Command ⌘").tag(Defaults[.Int64maskCommand])
                }
                .labelsHidden()
                .fixedSize()
                .onChange(of: keybindModel.modifierKey) { newValue in
                    if let currentKeybind = keybindModel.currentKeybind, currentKeybind.keyCode != 0 {
                        let updatedKeybind = UserKeyBind(keyCode: currentKeybind.keyCode, modifierFlags: newValue)
                        Defaults[.UserKeybind] = updatedKeybind
                        keybindModel.currentKeybind = updatedKeybind
                    }
                }

                Text(verbatim: "+")
                    .foregroundStyle(.secondary)

                if let keybind = keybindModel.currentKeybind, keybind.keyCode != 0 {
                    KeyCapView(text: KeyboardLabel.localizedKey(for: keybind.keyCode), symbol: nil)
                } else {
                    Text("No shortcut set").foregroundStyle(.secondary)
                }

                Button(keybindModel.isRecording ? "Press shortcut…" : "Change…") {
                    keybindModel.isRecording.toggle()
                }
                .buttonStyle(.settings)
                .disabled(keybindModel.isRecording)

                SettingsResetButton(isModified: !isDefaultShortcut) {
                    Defaults[.UserKeybind] = Self.defaultKeybind
                    keybindModel.currentKeybind = Self.defaultKeybind
                    keybindModel.modifierKey = Self.defaultKeybind.modifierFlags
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

    private static let defaultKeybind = UserKeyBind(keyCode: 48, modifierFlags: Defaults[.Int64maskAlternate])

    private var isDefaultShortcut: Bool {
        keybindModel.currentKeybind?.keyCode == Self.defaultKeybind.keyCode
            && keybindModel.currentKeybind?.modifierFlags == Self.defaultKeybind.modifierFlags
    }

    // MARK: - Fullscreen App Blacklist

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
                .buttonStyle(.settings)

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
}
