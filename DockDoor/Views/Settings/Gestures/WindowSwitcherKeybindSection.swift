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
    @Default(.additionalAlternateKeybinds) var additionalAlternateKeybinds
    @Default(.requireShiftTabToGoBack) var requireShiftTabToGoBack
    @Default(.switcherBackwardKeyCode) var switcherBackwardKeyCode
    @Default(.windowSwitcherSelectionKeyCode) var selectionKeyCode
    @Default(.enableVimMotions) var enableVimMotions
    @Default(.passArrowsThroughToSystem) var passArrowsThroughToSystem
    @Default(.showSettingsDescriptions) var showSettingsDescriptions

    @StateObject private var keybindModel = KeybindModel()
    @State private var showingAddBlacklistAppSheet = false
    @State private var newBlacklistApp = ""

    var body: some View {
        SettingsSection("Window Switcher Shortcuts") {
            initializerRow
                .settingsSearchTarget("gestures.switcherKeybind")
                .settingsAnnotation("Click the modifier keys to toggle them; you can combine several. Either left or right Command, Option, or Control keys work. You can also hold the modifiers while pressing the trigger to capture them all.")

            triggerKeyRow

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

        Section {
            alternateShortcutRow(firstAlternate, index: 0, canRemove: alternateKeybindKey != 0 || !additionalAlternateKeybinds.isEmpty, onRemove: removeFirstAlternate)
                .settingsSearchTarget("gestures.alternateShortcut")

            ForEach(Array($additionalAlternateKeybinds.enumerated()), id: \.element.id) { offset, alternate in
                let id = alternate.wrappedValue.id
                alternateShortcutRow(alternate, index: offset + 1, canRemove: true) {
                    additionalAlternateKeybinds.removeAll { $0.id == id }
                }
            }

            Button {
                additionalAlternateKeybinds.append(AlternateKeybind())
            } label: {
                Label("Add Alternate Shortcut", systemImage: "plus")
            }
            .buttonStyle(.settings)
        } header: {
            VStack(alignment: .leading, spacing: 3) {
                Text("Alternate Shortcuts")
                if showSettingsDescriptions {
                    Text("Additional trigger keys, each with its own modifier if desired, invoking the switcher with a different filter mode.")
                        .font(.footnote)
                        .fontWeight(.regular)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Alternate shortcuts with no modifiers selected use the main shortcut's modifiers.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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

        SettingsListSection(
            title: "Fullscreen App Blacklist",
            footer: "Apps in this list will not respond to window switcher shortcuts when in fullscreen mode.",
            items: fullscreenAppBlacklist,
            itemIcon: "app",
            emptyText: "No apps in blacklist",
            addTitle: "Add App",
            onAdd: { showingAddBlacklistAppSheet = true },
            onRemove: { appName in fullscreenAppBlacklist.removeAll { $0 == appName } },
            onRemoveAll: { fullscreenAppBlacklist.removeAll() }
        )
        .settingsSearchTarget("gestures.fullscreenBlacklist")
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

    // MARK: - Shortcut

    private var initializerRow: some View {
        LabeledContent("Initializer") {
            ModifierKeyToggles(modifierFlags: $keybindModel.modifierKey)
        }
        .onChange(of: keybindModel.modifierKey) { newValue in
            if let currentKeybind = keybindModel.currentKeybind, currentKeybind.keyCode != 0 {
                let updatedKeybind = UserKeyBind(keyCode: currentKeybind.keyCode, modifierFlags: newValue)
                Defaults[.UserKeybind] = updatedKeybind
                keybindModel.currentKeybind = updatedKeybind
            }
        }
    }

    private var triggerKeyRow: some View {
        LabeledContent("Trigger Key") {
            HStack(spacing: 8) {
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
                .frame(width: 16)
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

    // MARK: - Alternate Shortcuts

    private var firstAlternate: Binding<AlternateKeybind> {
        Binding(
            get: {
                AlternateKeybind(keyCode: alternateKeybindKey, modifierFlags: alternateKeybindModifierFlags, mode: alternateKeybindMode)
            },
            set: { AlternateKeybind.first = $0 }
        )
    }

    private func removeFirstAlternate() {
        if additionalAlternateKeybinds.isEmpty {
            alternateKeybindKey = 0
        } else {
            AlternateKeybind.first = additionalAlternateKeybinds.removeFirst()
        }
    }

    private func alternateShortcutRow(_ alternate: Binding<AlternateKeybind>, index: Int, canRemove: Bool, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            ModifierKeyToggles(modifierFlags: alternate.modifierFlags, compact: true, inheritedModifierFlags: keybindModel.modifierKey)
            Text("+")
                .foregroundStyle(.secondary)

            KeyCaptureButton(keyCode: alternate.keyCode, emptyLabel: "Not set", allowsEscape: true)

            if isConflictingAlternate(at: index) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .help(String(localized: "This shortcut is already used by another window switcher shortcut."))
            }

            Spacer()

            Picker("Mode", selection: alternate.mode) {
                ForEach(SwitcherInvocationMode.allCases) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            }
            .labelsHidden()
            .fixedSize()

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Remove alternate shortcut"))
            .accessibilityLabel(String(localized: "Remove alternate shortcut"))
            .opacity(canRemove ? 1 : 0)
            .disabled(!canRemove)
        }
    }

    private func isConflictingAlternate(at index: Int) -> Bool {
        let primary = keybindModel.currentKeybind ?? Defaults[.UserKeybind]
        let resolved = AlternateKeybind.all.map {
            $0.resolved(primaryModifierFlags: primary.modifierFlags)
        }
        guard resolved.indices.contains(index), let current = resolved[index] else { return false }
        let matches = { (other: UserKeyBind) in
            other.keyCode == current.keyCode && other.modifierFlags == current.modifierFlags
        }
        return matches(primary) || resolved.prefix(index).compactMap { $0 }.contains(where: matches)
    }

    private static let defaultKeybind = UserKeyBind(keyCode: 48, modifierFlags: Defaults[.Int64maskAlternate])

    private var isDefaultShortcut: Bool {
        keybindModel.currentKeybind?.keyCode == Self.defaultKeybind.keyCode
            && keybindModel.currentKeybind?.modifierFlags == Self.defaultKeybind.modifierFlags
    }
}
