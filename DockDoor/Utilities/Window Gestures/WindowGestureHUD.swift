import AppKit
import Defaults
import SwiftUI

enum WindowGestureOverlays {
    private static let lock = NSLock()
    private static var windowNumbers: Set<Int> = []

    static func register(_ windowNumber: Int) {
        guard windowNumber > 0 else { return }
        lock.lock()
        windowNumbers.insert(windowNumber)
        lock.unlock()
    }

    static func contains(_ windowNumber: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return windowNumbers.contains(windowNumber)
    }
}

@MainActor
final class WindowGestureHUD {
    struct Content {
        let title: String
        let symbolName: String
        var region: SnapRegion?
        var appIcon: NSImage?
        var isDimmed = false
    }

    private static let cursorOffset = CGPoint(x: 18, y: -34)
    private static let flashDuration: TimeInterval = 0.7

    private var tooltipPanel: NSPanel?
    private let tooltipView: NSHostingView<WindowGestureTooltip> = {
        let view = NSHostingView(rootView: WindowGestureTooltip(content: nil, backgroundAppearance: .resolve()))
        view.sizingOptions = [.intrinsicContentSize]
        return view
    }()

    private var previewPanel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    func show(_ content: Content, cursor: CGPoint, preview: CGRect?) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        showTooltip(content, cursor: cursor)
        showPreview(Defaults[.windowGestureLivePreview] ? preview : nil)
    }

    func flash(_ content: Content, cursor: CGPoint) {
        show(content, cursor: cursor, preview: nil)
        scheduleHide(after: Self.flashDuration)
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        fadeOut(tooltipPanel)
        fadeOut(previewPanel)
    }

    func finish(_ content: Content?, cursor: CGPoint) {
        guard let content else {
            hide()
            return
        }
        showPreview(nil)
        showTooltip(content, cursor: cursor)
        scheduleHide(after: 0.35)
    }

    static func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard Defaults[.windowGestureHaptics] else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    // MARK: - Tooltip

    private func showTooltip(_ content: Content, cursor: CGPoint) {
        let panel = tooltipPanel ?? makeTooltipPanel()
        tooltipPanel = panel

        tooltipView.rootView = WindowGestureTooltip(content: content, backgroundAppearance: .resolve())
        let size = tooltipView.fittingSize
        let screen = NSScreen.screenFromQuartzPoint(cursor)
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        var origin = CGPoint(x: cursor.x + Self.cursorOffset.x, y: primaryMaxY - cursor.y + Self.cursorOffset.y - size.height / 2)
        let bounds = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)

        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.invalidateShadow()
        fadeIn(panel)
    }

    private func makeTooltipPanel() -> NSPanel {
        let panel = Self.makePanel(level: NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow))))
        panel.hasShadow = true
        panel.contentView = tooltipView
        return panel
    }

    // MARK: - Preview

    private func showPreview(_ frame: CGRect?) {
        guard let frame, frame.width > 1, frame.height > 1 else {
            fadeOut(previewPanel)
            return
        }

        if let panel = previewPanel, panel.isVisible, panel.alphaValue > 0 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
                panel.animator().alphaValue = 1
            }
            return
        }

        let panel = previewPanel ?? makePreviewPanel()
        previewPanel = panel
        panel.setFrame(frame, display: true)
        fadeIn(panel)
    }

    private func makePreviewPanel() -> NSPanel {
        let panel = Self.makePanel(level: .floating)
        panel.hasShadow = false
        panel.contentView = WindowGesturePreviewView()
        return panel
    }

    // MARK: - Visibility

    private static func makePanel(level: NSWindow.Level) -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = level
        panel.alphaValue = 0
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle, .transient]
        return panel
    }

    private func fadeIn(_ panel: NSPanel) {
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            WindowGestureOverlays.register(panel.windowNumber)
        }
        guard panel.alphaValue < 1 else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 1
        }
    }

    private func fadeOut(_ panel: NSPanel?) {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.14
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated {
                if panel.alphaValue == 0 {
                    panel.orderOut(nil)
                }
            }
        })
    }

    private func scheduleHide(after delay: TimeInterval) {
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.hide()
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}

private struct WindowGestureTooltip: View {
    let content: WindowGestureHUD.Content?
    let backgroundAppearance: BackgroundAppearance

    var body: some View {
        if let content {
            HStack(spacing: 6) {
                if let appIcon = content.appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 18, height: 18)
                } else if let region = content.region {
                    SnapRegionGlyph(region: region)
                        .frame(width: 22, height: 14)
                } else {
                    Image(systemName: content.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(content.isDimmed ? Color.secondary : Color.accentColor)
                }
                Text(content.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(content.isDimmed ? .secondary : .primary)
                    .lineLimit(1)
            }
            .fixedSize()
            .materialPill(backgroundAppearance: backgroundAppearance)
        }
    }
}

private struct SnapRegionGlyph: View {
    let region: SnapRegion

    var body: some View {
        Canvas { context, size in
            let outer = CGRect(origin: .zero, size: size).insetBy(dx: 0.75, dy: 0.75)
            context.stroke(Path(roundedRect: outer, cornerRadius: 3), with: .color(.secondary), lineWidth: 1.2)
            let inner = outer.insetBy(dx: 2, dy: 2)
            let fill = region.frame(in: CGRect(origin: .zero, size: inner.size))
            let flipped = CGRect(x: inner.minX + fill.minX, y: inner.minY + inner.height - fill.maxY, width: fill.width, height: fill.height)
            context.fill(Path(roundedRect: flipped, cornerRadius: 1.5), with: .color(.accentColor))
        }
    }
}

private final class WindowGesturePreviewView: NSView {
    private let background = NSVisualEffectView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.alphaValue = 0.55
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true
        background.autoresizingMask = [.width, .height]
        addSubview(background)

        let border = NSView()
        border.wantsLayer = true
        border.layer?.cornerRadius = 12
        border.layer?.cornerCurve = .continuous
        border.layer?.borderWidth = 2
        border.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.75).cgColor
        border.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        border.autoresizingMask = [.width, .height]
        addSubview(border)
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let inset: CGFloat = bounds.width > 8 && bounds.height > 8 ? 4 : 0
        for subview in subviews {
            subview.frame = bounds.insetBy(dx: inset, dy: inset)
        }
    }
}
