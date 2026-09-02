import AppKit
import Combine
import SwiftUI

/// AppKit-backed scroll container for preview cards. Each card keeps its SwiftUI view in its own hosting view, and scrolling moves the content view's origin instead of an NSClipView so the hosting views are never asked to re-render per frame.
struct CardGridScrollView: NSViewRepresentable {
    struct Layout: Equatable {
        let lines: [[FlowItem]]
        let isHorizontal: Bool
        let scrollsVertically: Bool
        let centerLines: Bool
        let spacing: CGFloat
        let inset: CGFloat
        let dimensions: [Int: WindowPreviewHoverContainer.WindowDimensions]
        let appearance: PreviewAppearanceSettings
        let compact: Bool
    }

    let layout: Layout
    let contentKey: [WindowInfo.ViewSnapshot]
    let coordinator: PreviewStateCoordinator
    @Binding var scrolledFromStart: Bool
    let makeCard: (FlowItem) -> AnyView

    func makeNSView(context: Context) -> ContainerView {
        let container = ContainerView(scrollsVertically: layout.scrollsVertically)
        context.coordinator.attach(container: container, representable: self)
        return container
    }

    func updateNSView(_ container: ContainerView, context: Context) {
        context.coordinator.update(representable: self)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ContainerView, context: Context) -> CGSize? {
        let content = context.coordinator.contentSize
        return CGSize(
            width: proposal.width.map { min($0, content.width) } ?? content.width,
            height: proposal.height.map { min($0, content.height) } ?? content.height
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Scrolling translates the content layer only; view frames are committed once the gesture settles so per-frame work is a single CA transform, while hit-testing and tracking areas stay exact after every gesture.
    final class ContainerView: NSView {
        let contentView = FlippedView()
        var scrollsVertically: Bool {
            didSet {
                guard scrollsVertically != oldValue else { return }
                setOffset(0)
                commit()
            }
        }
        var onOffsetChange: ((CGFloat) -> Void)?

        var contentSize: CGSize = .zero {
            didSet {
                contentView.frame.size = contentSize
                setOffset(offset)
            }
        }

        private(set) var offset: CGFloat = 0
        private var committedOffset: CGFloat = 0
        private var commitTimer: Timer?

        var maxOffset: CGFloat {
            max(0, scrollsVertically ? contentSize.height - bounds.height : contentSize.width - bounds.width)
        }

        init(scrollsVertically: Bool) {
            self.scrollsVertically = scrollsVertically
            super.init(frame: .zero)
            wantsLayer = true
            layer?.masksToBounds = true
            contentView.wantsLayer = true
            addSubview(contentView)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override var isFlipped: Bool { true }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            setOffset(offset)
            commit()
        }

        override func scrollWheel(with event: NSEvent) {
            let primary = scrollsVertically ? event.scrollingDeltaY : event.scrollingDeltaX
            let secondary = scrollsVertically ? event.scrollingDeltaX : event.scrollingDeltaY
            var delta = primary != 0 ? primary : secondary
            if !event.hasPreciseScrollingDeltas { delta *= 10 }
            if delta != 0 { setOffset(offset - delta) }

            let gestureEnded = event.phase == .ended || event.phase == .cancelled || event.momentumPhase == .ended
            let stillGoing = event.phase == .changed || event.momentumPhase == .changed || event.momentumPhase == .began
            if gestureEnded {
                commit()
            } else if !stillGoing {
                scheduleCommit()
            }
        }

        func scrollBy(_ delta: CGFloat) {
            setOffset(offset + delta)
            scheduleCommit()
        }

        func scroll(to newOffset: CGFloat, animated: Bool) {
            let target = max(0, min(newOffset, maxOffset))
            if animated {
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.15)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
                CATransaction.setCompletionBlock { [weak self] in self?.commit() }
                setOffset(target)
                CATransaction.commit()
            } else {
                setOffset(target)
                commit()
            }
        }

        private func setOffset(_ newOffset: CGFloat) {
            let clamped = max(0, min(newOffset, maxOffset))
            let changed = clamped != offset
            offset = clamped
            let visualShift = committedOffset - clamped
            contentView.layer?.sublayerTransform = scrollsVertically
                ? CATransform3DMakeTranslation(0, visualShift, 0)
                : CATransform3DMakeTranslation(visualShift, 0, 0)
            if changed { onOffsetChange?(clamped) }
        }

        private func scheduleCommit() {
            commitTimer?.invalidate()
            commitTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in self?.commit() }
        }

        private func commit() {
            commitTimer?.invalidate()
            commitTimer = nil
            guard committedOffset != offset else { return }
            committedOffset = offset
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            contentView.frame.origin = scrollsVertically ? CGPoint(x: 0, y: -offset) : CGPoint(x: -offset, y: 0)
            contentView.layer?.sublayerTransform = CATransform3DIdentity
            CATransaction.commit()
        }
    }

    final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    final class Coordinator {
        private weak var container: ContainerView?
        private var hostingViews: [FlowItem: NSHostingView<AnyView>] = [:]
        private var frames: [FlowItem: CGRect] = [:]
        private var layout: Layout?
        private var contentKey: [WindowInfo.ViewSnapshot] = []
        private var previewCoordinator: PreviewStateCoordinator?
        private var scrolledFromStart: Binding<Bool>?
        private var makeCard: ((FlowItem) -> AnyView)?
        private var pendingItems: [FlowItem] = []
        private var cancellables: Set<AnyCancellable> = []
        private(set) var contentSize: CGSize = .zero

        func attach(container: ContainerView, representable: CardGridScrollView) {
            self.container = container
            previewCoordinator = representable.coordinator
            scrolledFromStart = representable.$scrolledFromStart

            container.onOffsetChange = { [weak self] offset in self?.offsetChanged(offset) }

            representable.coordinator.selection.$currIndex
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] index in self?.scrollToSelection(index) }
                .store(in: &cancellables)

            update(representable: representable)
        }

        func update(representable: CardGridScrollView) {
            guard let container else { return }
            scrolledFromStart = representable.$scrolledFromStart

            if layout != representable.layout {
                layout = representable.layout
                contentKey = representable.contentKey
                container.scrollsVertically = representable.layout.scrollsVertically
                rebuild(in: container, representable: representable)
            } else if contentKey != representable.contentKey {
                contentKey = representable.contentKey
                makeCard = representable.makeCard
                for (item, hostingView) in hostingViews {
                    hostingView.rootView = representable.makeCard(item)
                }
            }
        }

        private func rebuild(in container: ContainerView, representable: CardGridScrollView) {
            let layout = representable.layout
            makeCard = representable.makeCard
            let items = layout.lines.flatMap { $0 }
            let itemSet = Set(items)

            for (item, view) in hostingViews where !itemSet.contains(item) {
                view.removeFromSuperview()
                hostingViews.removeValue(forKey: item)
            }
            for (item, view) in hostingViews {
                view.rootView = representable.makeCard(item)
            }

            var sizes: [FlowItem: CGSize] = [:]
            var sizesByClass: [SizeClass: CGSize] = [:]
            for item in items {
                let sizeClass = SizeClass(item: item, layout: layout, coordinator: previewCoordinator)
                if let sizeClass, let measured = sizesByClass[sizeClass] {
                    sizes[item] = measured
                    continue
                }
                let view = ensureView(for: item, in: container.contentView)
                view.sizingOptions = .intrinsicContentSize
                let measured = view.fittingSize
                view.sizingOptions = []
                sizes[item] = measured
                if let sizeClass { sizesByClass[sizeClass] = measured }
            }

            frames = Self.frames(for: layout, sizes: sizes)
            let maxX = frames.values.map(\.maxX).max() ?? 0
            let maxY = frames.values.map(\.maxY).max() ?? 0
            contentSize = CGSize(width: maxX + layout.inset, height: maxY + layout.inset)
            container.contentSize = contentSize

            // Cards that cannot be on screen at open are created after the first frame so opening pays only for the visible rows.
            let eagerExtent = NSScreen.main.map { layout.isHorizontal ? $0.visibleFrame.height : $0.visibleFrame.width } ?? .greatestFiniteMagnitude
            pendingItems = []
            for item in items {
                guard let frame = frames[item] else { continue }
                let leadingEdge = layout.isHorizontal ? frame.minY : frame.minX
                if hostingViews[item] != nil || leadingEdge <= eagerExtent {
                    ensureView(for: item, in: container.contentView).frame = frame
                } else {
                    pendingItems.append(item)
                }
            }
            if !pendingItems.isEmpty {
                DispatchQueue.main.async { [weak self] in self?.materializePending(onlyVisible: false) }
            }
        }

        @discardableResult
        private func ensureView(for item: FlowItem, in contentView: NSView) -> NSHostingView<AnyView> {
            if let existing = hostingViews[item] { return existing }
            let view = NSHostingView(rootView: makeCard?(item) ?? AnyView(EmptyView()))
            view.sizingOptions = []
            if let frame = frames[item] { view.frame = frame }
            contentView.addSubview(view)
            hostingViews[item] = view
            return view
        }

        private func materializePending(onlyVisible: Bool) {
            guard let container, !pendingItems.isEmpty else { return }
            let visible = container.contentView.convert(container.bounds, from: container).insetBy(dx: -200, dy: -200)
            pendingItems.removeAll { item in
                guard let frame = frames[item] else { return true }
                guard !onlyVisible || frame.intersects(visible) else { return false }
                ensureView(for: item, in: container.contentView)
                return true
            }
        }

        /// Cards with the same image dimensions and the same chrome share one measurement.
        private struct SizeClass: Hashable {
            let width: CGFloat
            let height: CGFloat
            let hasTitle: Bool
            let windowless: Bool
            let hasImage: Bool

            init?(item: FlowItem, layout: Layout, coordinator: PreviewStateCoordinator?) {
                guard case let .window(index) = item, let coordinator, index < coordinator.windows.count,
                      let dims = layout.dimensions[index]
                else { return nil }
                let window = coordinator.windows[index]
                width = dims.size.width
                height = dims.size.height
                hasTitle = !(window.windowName ?? "").isEmpty && window.windowName != window.app.localizedName
                windowless = window.isWindowlessApp
                hasImage = window.image != nil
            }
        }

        private static func frames(for layout: Layout, sizes: [FlowItem: CGSize]) -> [FlowItem: CGRect] {
            var frames: [FlowItem: CGRect] = [:]
            let lineExtents: [CGFloat] = layout.lines.map { line in
                let itemExtents = line.map { layout.isHorizontal ? (sizes[$0]?.width ?? 0) : (sizes[$0]?.height ?? 0) }
                return itemExtents.reduce(0, +) + CGFloat(max(0, line.count - 1)) * layout.spacing
            }
            let longestLine = lineExtents.max() ?? 0

            var cross = layout.inset
            for (lineIndex, line) in layout.lines.enumerated() {
                let lineThickness = line.map { layout.isHorizontal ? (sizes[$0]?.height ?? 0) : (sizes[$0]?.width ?? 0) }.max() ?? 0
                var along = layout.inset + (layout.centerLines ? (longestLine - lineExtents[lineIndex]) / 2 : 0)
                for item in line {
                    let size = sizes[item] ?? .zero
                    if layout.isHorizontal {
                        frames[item] = CGRect(x: along, y: cross + (lineThickness - size.height) / 2, width: size.width, height: size.height)
                        along += size.width + layout.spacing
                    } else {
                        frames[item] = CGRect(x: cross, y: along, width: size.width, height: size.height)
                        along += size.height + layout.spacing
                    }
                }
                cross += lineThickness + layout.spacing
            }
            return frames
        }

        private func offsetChanged(_ offset: CGFloat) {
            materializePending(onlyVisible: true)
            let scrolled = offset > 1
            if scrolledFromStart?.wrappedValue != scrolled {
                scrolledFromStart?.wrappedValue = scrolled
            }
        }

        private func scrollToSelection(_ index: Int) {
            guard let container, let previewCoordinator, previewCoordinator.shouldScrollToIndex,
                  let frame = frames[.window(index)]
            else { return }
            let visible = container.contentView.convert(container.bounds, from: container)
            guard !visible.contains(frame) else { return }
            let target = container.scrollsVertically
                ? frame.midY - visible.height / 2
                : frame.midX - visible.width / 2
            container.scroll(to: target, animated: true)
        }
    }
}
