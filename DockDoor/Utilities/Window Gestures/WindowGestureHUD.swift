import AppKit
import Defaults

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
    private let tooltipView = WindowGestureTooltipView()
    private var previewPanel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?
    private var cursorHidden = false

    func show(_ content: Content, cursor: CGPoint, preview: CGRect?) {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        showTooltip(content, cursor: cursor)
        showPreview(Defaults[.windowGestureLivePreview] ? preview : nil)
        hideCursorIfNeeded()
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
        showCursorIfNeeded()
    }

    func finish(_ content: Content?, cursor: CGPoint) {
        guard let content else {
            hide()
            return
        }
        showPreview(nil)
        showTooltip(content, cursor: cursor)
        showCursorIfNeeded()
        scheduleHide(after: 0.35)
    }

    static func haptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard Defaults[.windowGestureHaptics] else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    // MARK: - Tooltip

    private func showTooltip(_ content: Content, cursor: CGPoint) {
        guard Defaults[.windowGestureShowTooltips] else {
            fadeOut(tooltipPanel)
            return
        }
        let panel = tooltipPanel ?? makeTooltipPanel()
        tooltipPanel = panel

        tooltipView.update(content, scale: Defaults[.windowGestureTooltipSize].scale)
        let size = tooltipView.fittingSize
        let screen = NSScreen.screenFromQuartzPoint(cursor)
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        var origin = CGPoint(x: cursor.x + Self.cursorOffset.x, y: primaryMaxY - cursor.y + Self.cursorOffset.y - size.height / 2)
        let bounds = screen.visibleFrame.insetBy(dx: 8, dy: 8)
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)

        panel.setFrame(CGRect(origin: origin, size: size), display: true)
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

    // MARK: - Cursor

    private func hideCursorIfNeeded() {
        guard !cursorHidden, Defaults[.windowGestureHideCursor] else { return }
        let connection = CGSMainConnectionID()
        _ = CGSSetConnectionProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        CGDisplayHideCursor(CGMainDisplayID())
        cursorHidden = true
    }

    private func showCursorIfNeeded() {
        guard cursorHidden else { return }
        CGDisplayShowCursor(CGMainDisplayID())
        cursorHidden = false
    }
}

private final class WindowGestureTooltipView: NSView {
    private let background = NSVisualEffectView()
    private let iconView = NSImageView()
    private let glyphView = SnapRegionGlyphView()
    private let label = NSTextField(labelWithString: "")
    private let stack = NSStackView()

    init() {
        super.init(frame: .zero)
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(glyphView)
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(label)
        background.addSubview(stack)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 7),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -7),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var iconWidth: NSLayoutConstraint?
    private var iconHeight: NSLayoutConstraint?
    private var glyphWidth: NSLayoutConstraint?
    private var glyphHeight: NSLayoutConstraint?

    func update(_ content: WindowGestureHUD.Content, scale: CGFloat) {
        label.stringValue = content.title
        label.font = .systemFont(ofSize: (13 * scale).rounded(), weight: .semibold)
        label.textColor = content.isDimmed ? .secondaryLabelColor : .labelColor

        let iconSide = (20 * scale).rounded()
        if let appIcon = content.appIcon {
            iconView.image = appIcon
            iconView.contentTintColor = nil
        } else {
            let configuration = NSImage.SymbolConfiguration(pointSize: (14 * scale).rounded(), weight: .semibold)
            iconView.image = NSImage(systemSymbolName: content.symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration)
            iconView.contentTintColor = content.isDimmed ? .secondaryLabelColor : .controlAccentColor
        }
        iconView.isHidden = content.region != nil && content.appIcon == nil
        glyphView.region = content.region
        glyphView.isHidden = content.region == nil

        iconWidth?.isActive = false
        iconHeight?.isActive = false
        glyphWidth?.isActive = false
        glyphHeight?.isActive = false
        iconWidth = iconView.widthAnchor.constraint(equalToConstant: iconSide)
        iconHeight = iconView.heightAnchor.constraint(equalToConstant: iconSide)
        glyphWidth = glyphView.widthAnchor.constraint(equalToConstant: (30 * scale).rounded())
        glyphHeight = glyphView.heightAnchor.constraint(equalToConstant: (20 * scale).rounded())
        NSLayoutConstraint.activate([iconWidth, iconHeight, glyphWidth, glyphHeight].compactMap { $0 })
        layoutSubtreeIfNeeded()
    }
}

private final class SnapRegionGlyphView: NSView {
    var region: SnapRegion? {
        didSet { needsDisplay = true }
    }

    override func draw(_: NSRect) {
        guard let region else { return }
        let outer = bounds.insetBy(dx: 1, dy: 1)
        let outline = NSBezierPath(roundedRect: outer, xRadius: 3, yRadius: 3)
        NSColor.secondaryLabelColor.setStroke()
        outline.lineWidth = 1.2
        outline.stroke()

        let inner = outer.insetBy(dx: 2, dy: 2)
        let fill = region.frame(in: inner, spacing: 0, includeEdges: false)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: fill, xRadius: 1.5, yRadius: 1.5).fill()
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
        for subview in subviews {
            subview.frame = bounds.insetBy(dx: 4, dy: 4)
        }
    }
}
