import AppKit
import Carbon
import Defaults
import SwiftUI

class KeybindModel: ObservableObject {
    @Published var modifierKey: Int
    @Published var isRecording: Bool = false
    @Published var currentKeybind: UserKeyBind?

    init() {
        modifierKey = Defaults[.UserKeybind].modifierFlags
        currentKeybind = Defaults[.UserKeybind]
    }
}

struct WindowSwitcherSettingsView: View {
    @Default(.enableWindowSwitcher) var enableWindowSwitcher
    @Default(.includeHiddenWindowsInSwitcher) var includeHiddenWindowsInSwitcher
    @Default(.windowSwitcherPlacementStrategy) var placementStrategy
    @Default(.pinnedScreenIdentifier) var pinnedScreenIdentifier
    @Default(.useClassicWindowOrdering) private var useClassicWindowOrdering
    @StateObject private var viewModel = KeybindModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle(isOn: $enableWindowSwitcher) {
                    Text("Enable Window Switcher")
                }
                .onChange(of: enableWindowSwitcher) { newValue in
                    askUserToRestartApplication()
                }
                Spacer()
            }

            if enableWindowSwitcher {
                Divider()

                Toggle(isOn: $includeHiddenWindowsInSwitcher, label: {
                    Text("Include Hidden and Minimized Windows in the Window Switcher")
                })

                Text("Set Initialization Key and Keybind")
                    .font(.headline)
                    .padding(.top, 10)

                Picker("Initialization Key", selection: $viewModel.modifierKey) {
                    Text("Control (⌃)").tag(Defaults[.Int64maskControl])
                    Text("Option (⌥)").tag(Defaults[.Int64maskAlternate])
                    Text("Command (⌘)").tag(Defaults[.Int64maskCommand])
                }
                .pickerStyle(SegmentedPickerStyle())
                .scaledToFit()
                .layoutPriority(1)
                .onChange(of: viewModel.modifierKey) { newValue  in
                    if let currentKeybind = viewModel.currentKeybind {
                        let updatedKeybind = UserKeyBind(keyCode: currentKeybind.keyCode, modifierFlags: newValue)
                        Defaults[.UserKeybind] = updatedKeybind
                        viewModel.currentKeybind = updatedKeybind
                    }
                }

                Text("Important: When recording, press ONLY the trigger key (e.g. just press Tab if you want command + Tab). Do not press the initialization key during recording.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: { viewModel.isRecording.toggle() }) {
                    Text(viewModel.isRecording ? String(localized: "Press any key...") : String(localized: "Start recording trigger key"))
                }
                .keyboardShortcut(.defaultAction)

                if let keybind = viewModel.currentKeybind {
                    Text("Current Keybind: \(stringForCurrentKeybind(keybind))")
                        .font(.subheadline)
                        .padding(.top, 5)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Example:")
                        .font(.body)

                    Text("1. Select \"Command (⌘)\" as the initialization key.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("2. Click \"Start Recording Trigger Key\".")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("3. Press ONLY the Tab key (not Command+Tab).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("4. Your keybind will be set to Command+Tab.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Window Switcher Placement")
                    .font(.headline)
                    .padding(.top, 10)

                Picker("Placement Strategy", selection: $placementStrategy) {
                    ForEach(WindowSwitcherPlacementStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.localizedName).tag(strategy)
                    }
                }
                .labelsHidden()
                .onChange(of: placementStrategy) { newStrategy in
                    if newStrategy == .pinnedToScreen, pinnedScreenIdentifier.isEmpty {
                        // Initialize with main screen when first selecting pinned screen option
                        pinnedScreenIdentifier = NSScreen.main?.uniqueIdentifier() ?? ""
                    }
                }

                if placementStrategy == .pinnedToScreen {
                    VStack(alignment: .leading, spacing: 4) {
                        Picker("Pin to Screen", selection: $pinnedScreenIdentifier) {
                            // Add options for all current screens
                            ForEach(NSScreen.screens, id: \.self) { screen in
                                Text(screenDisplayName(screen))
                                    .tag(screen.uniqueIdentifier())
                            }

                            // Add option for disconnected screen if the stored identifier isn't found
                            if !pinnedScreenIdentifier.isEmpty,
                               !NSScreen.screens.contains(where: { $0.uniqueIdentifier() == pinnedScreenIdentifier })
                            {
                                Text(String(localized: "Disconnected Display"))
                                    .tag(pinnedScreenIdentifier)
                            }
                        }
                        .labelsHidden()

                        if !pinnedScreenIdentifier.isEmpty,
                           !NSScreen.screens.contains(where: { $0.uniqueIdentifier() == pinnedScreenIdentifier })
                        {
                            Text("This display is currently disconnected. The window switcher will appear on the main display until the selected display is reconnected.",
                                 comment: "Message shown when a pinned display is disconnected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(alignment: .leading) {
                    Toggle(isOn: $useClassicWindowOrdering) {
                        Text("Use Windows-style window ordering in the window switcher")
                    }
                    Text("When enabled, shows the last active window first instead of the current window")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 650)
        .background(
            ShortcutCaptureView(
                currentKeybind: $viewModel.currentKeybind,
                isRecording: $viewModel.isRecording,
                modifierKey: $viewModel.modifierKey
            )
        )
        .onAppear {
            viewModel.modifierKey = Defaults[.UserKeybind].modifierFlags
            viewModel.currentKeybind = Defaults[.UserKeybind]
        }
    }

    func stringForCurrentKeybind(_ shortcut: UserKeyBind) -> String {
        var parts: [String] = []
        parts.append(modifierConverter.toString(shortcut.modifierFlags))
        parts.append(KeyCodeConverter.toString(shortcut.keyCode))
        return parts.joined(separator: " ")
    }

    private func screenDisplayName(_ screen: NSScreen) -> String {
        let isMain = screen == NSScreen.main

        if !screen.localizedName.isEmpty {
            return "\(screen.localizedName)\(isMain ? " (Main)" : "")"
        } else {
            return String(localized: "Disconnected Display")
        }
    }
}

class ShortcutCaptureViewController: NSViewController {
    weak var coordinator: ShortcutCaptureView.Coordinator?

    override func loadView() {
        view = NSView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(view)
    }

    override func keyDown(with event: NSEvent) {
        coordinator?.handleKeyEvent(event)
    }

    override func flagsChanged(with event: NSEvent) {
        coordinator?.handleKeyEvent(event)
    }
}

struct ShortcutCaptureView: NSViewControllerRepresentable {
    @Binding var currentKeybind: UserKeyBind?
    @Binding var isRecording: Bool
    @Binding var modifierKey: Int

    class Coordinator: NSObject {
        var parent: ShortcutCaptureView

        init(_ parent: ShortcutCaptureView) {
            self.parent = parent
        }

        func handleKeyEvent(_ event: NSEvent) {
            guard parent.isRecording else { return }

            if event.type == .keyDown {
                parent.isRecording = false
                let newKeybind = UserKeyBind(keyCode: UInt16(event.keyCode), modifierFlags: parent.modifierKey)
                Defaults[.UserKeybind] = newKeybind
                parent.currentKeybind = newKeybind
            } else if event.type == .flagsChanged {
                if event.modifierFlags.contains(.control) {
                    parent.modifierKey = Defaults[.Int64maskControl]
                } else if event.modifierFlags.contains(.option) {
                    parent.modifierKey = Defaults[.Int64maskAlternate]
                } else if event.modifierFlags.contains(.command) {
                    parent.modifierKey = Defaults[.Int64maskCommand]
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSViewController(context: Context) -> ShortcutCaptureViewController {
        let viewController = ShortcutCaptureViewController()
        viewController.coordinator = context.coordinator
        return viewController
    }

    func updateNSViewController(_ nsViewController: ShortcutCaptureViewController, context: Context) {
        nsViewController.view.window?.makeFirstResponder(nsViewController.view)
    }
}
