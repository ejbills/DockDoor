import Defaults
import SwiftUI

struct WindowSwitcherKeybindSection: View {
    @Default(.enableWindowSwitcher) var enableWindowSwitcher
    @Default(.fullscreenAppBlacklist) var fullscreenAppBlacklist
    @Default(.alternateKeybindKey) var alternateKeybindKey
    @Default(.alternateKeybindMode) var alternateKeybindMode

    @StateObject private var keybindModel = KeybindModel()
    @State private var showingAddBlacklistAppSheet = false
    @State private var newBlacklistApp = ""
    @State private var capturingAlternateKey = false
    @State private var keyMonitor: Any? = nil

    var body: some View {
        SettingsGroup(header: "Window Switcher Shortcuts") {
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

                keyboardShortcutSection
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
        .onAppear {
            keybindModel.modifierKey = Defaults[.UserKeybind].modifierFlags
            keybindModel.currentKeybind = Defaults[.UserKeybind]
        }
    }

    // MARK: - Keyboard Shortcut Section

    private var keyboardShortcutSection: some View {
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

    // MARK: - Alternate Shortcuts Section

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
