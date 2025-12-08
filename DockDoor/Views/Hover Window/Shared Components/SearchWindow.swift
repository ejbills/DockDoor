import AppKit
import Defaults
import SwiftUI

struct SearchFieldView: View {
    let searchField: NSTextField

    var body: some View {
        ZStack {
            BlurView(variant: 18, frostedTranslucentLayer: false)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                SearchTextFieldRepresentable(textField: searchField)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 40)
    }
}

struct SearchTextFieldRepresentable: NSViewRepresentable {
    let textField: NSTextField

    func makeNSView(context: Context) -> NSTextField {
        textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {}
}

class SearchWindow: NSPanel, NSTextFieldDelegate {
    private var searchField: NSTextField!
    private weak var previewCoordinator: PreviewStateCoordinator?

    init(previewCoordinator: PreviewStateCoordinator) {
        self.previewCoordinator = previewCoordinator
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setupWindow()
        setupSearchField()
    }

    var isFocused: Bool {
        (NSApp.keyWindow === self) && (searchField.currentEditor() != nil)
    }

    private func setupWindow() {
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
    }

    private func setupSearchField() {
        searchField = NSTextField()
        searchField.placeholderString = "Press / to search windows…"
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.backgroundColor = .clear
        searchField.focusRingType = .none
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.usesSingleLineMode = true
        searchField.delegate = self

        let searchView = SearchFieldView(searchField: searchField)
        let hostingView = NSHostingView(rootView: searchView)
        hostingView.frame = contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        previewCoordinator?.searchQuery = textField.stringValue
    }

    func showSearch(relativeTo window: NSWindow) {
        let frame = window.frame
        if frame.width <= 0 || frame.height <= 0 {
            DispatchQueue.main.async { [weak self] in
                self?.showSearch(relativeTo: window)
            }
            return
        }

        let verticalGap: CGFloat = Defaults[.windowSwitcherShowListView] ? -20 : 20

        var searchFrame = NSRect(
            x: frame.midX - 150,
            y: frame.maxY + verticalGap,
            width: 300,
            height: 40
        )

        if let screen = window.screen ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            if searchFrame.minX < screenFrame.minX {
                searchFrame.origin.x = screenFrame.minX + 10
            } else if searchFrame.maxX > screenFrame.maxX {
                searchFrame.origin.x = screenFrame.maxX - 310
            }
            if searchFrame.maxY > screenFrame.maxY {
                searchFrame.origin.y = frame.minY - 60
            }
        }

        setFrame(searchFrame, display: false)
        orderFront(nil)
    }

    func hideSearch() {
        orderOut(nil)
        searchField.stringValue = ""
        previewCoordinator?.searchQuery = ""
    }

    func updateSearchText(_ text: String) {
        guard searchField.stringValue != text else { return }
        searchField.stringValue = text
        if let editor = searchField.currentEditor() {
            editor.selectedRange = NSRange(location: text.count, length: 0)
        }
    }

    func focusSearchField() {
        makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            self.searchField.becomeFirstResponder()
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
