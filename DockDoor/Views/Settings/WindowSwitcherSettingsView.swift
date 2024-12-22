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
