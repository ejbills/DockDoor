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

                Text("Press any key to set the keybind.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: { viewModel.isRecording.toggle() }) {
                    Text(viewModel.isRecording ? "Press any key..." : "Start recording keybind")
                }
                .keyboardShortcut(.defaultAction)

                if let keybind = viewModel.currentKeybind {
                    Text("Current Keybind: \(stringForCurrentKeybind(keybind))")
                        .font(.subheadline)
                        .padding(.top, 5)
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
