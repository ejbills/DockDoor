import AppKit
import Carbon // For key codes, if still used by KeyCodeConverter, though UserKeyBind uses UInt16
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

struct KeyCapView: View {
    let text: String
    let symbol: String?

    var body: some View {
        HStack {
            if let symbol, !symbol.isEmpty {
                Image(systemName: symbol)
            } else {
                Text(text)
            }
        }
        .padding(8)
        .dockStyle()
    }
}

class ShortcutCaptureViewController: NSViewController {
    weak var coordinator: ShortcutCaptureView.Coordinator?

    override func loadView() {
        view = NSView()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if coordinator?.parent.isRecording ?? false {
            DispatchQueue.main.async { // Ensure UI updates on main thread
                self.view.window?.makeFirstResponder(self.view)
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        coordinator?.handleKeyEvent(event)
    }

    override func flagsChanged(with event: NSEvent) {
        // Modifiers are handled by the Picker in MainSettingsView
        // coordinator?.handleKeyEvent(event)
    }
}

struct ShortcutCaptureView: NSViewControllerRepresentable {
    typealias NSViewControllerType = ShortcutCaptureViewController
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
                let isModifierKeyAlone = (
                    event.keyCode == kVK_Shift || event.keyCode == kVK_RightShift ||
                        event.keyCode == kVK_Control || event.keyCode == kVK_RightControl ||
                        event.keyCode == kVK_Option || event.keyCode == kVK_RightOption ||
                        event.keyCode == kVK_Command || event.keyCode == kVK_RightCommand ||
                        event.keyCode == kVK_Function // Fn key
                ) && event.charactersIgnoringModifiers?.isEmpty == true

                if isModifierKeyAlone {
                    return // Ignore modifier keys pressed alone as the trigger
                }

                parent.isRecording = false
                let newKeybind = UserKeyBind(keyCode: UInt16(event.keyCode), modifierFlags: parent.modifierKey)
                Defaults[.UserKeybind] = newKeybind
                parent.currentKeybind = newKeybind
                DispatchQueue.main.async {
                    event.window?.makeFirstResponder(nil) // Resign first responder
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
        if isRecording {
            DispatchQueue.main.async {
                if nsViewController.view.window?.firstResponder != nsViewController.view {
                    nsViewController.view.window?.makeFirstResponder(nsViewController.view)
                }
            }
        } else {
            if nsViewController.view.window?.firstResponder == nsViewController.view {
                DispatchQueue.main.async {
                    nsViewController.view.window?.makeFirstResponder(nil)
                }
            }
        }
    }
}
