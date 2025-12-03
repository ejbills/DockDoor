import Cocoa
import Defaults

/// Observes dock orientation and size changes and notifies the coordinator when they change.
/// Uses NSApplication.didChangeScreenParametersNotification which fires when dock position/size affects screen's visibleFrame.
final class ActiveAppIndicatorOrientationObserver {
    private weak var coordinator: ActiveAppIndicatorCoordinator?
    private var screenParametersObserver: NSObjectProtocol?
    private var lastKnownDockPosition: DockPosition
    private var lastKnownDockSize: CGFloat

    init(coordinator: ActiveAppIndicatorCoordinator) {
        self.coordinator = coordinator
        lastKnownDockPosition = DockUtils.getDockPosition()
        lastKnownDockSize = DockUtils.getDockSize()
        setupObserver()
    }

    deinit {
        cleanup()
    }

    // MARK: - Setup

    private func setupObserver() {
        // Observe screen parameter changes (includes dock position changes)
        // When the Dock position changes, this notification fires because the main screen's
        // visibleFrame (which excludes the space occupied by the Dock) depends on the Dock's position.
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenParametersChanged()
        }
    }

    private func cleanup() {
        if let observer = screenParametersObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        screenParametersObserver = nil
    }

    // MARK: - Event Handling

    private func handleScreenParametersChanged() {
        let newDockPosition = DockUtils.getDockPosition()
        let newDockSize = DockUtils.getDockSize()

        // Check if dock position changed
        if newDockPosition != lastKnownDockPosition {
            lastKnownDockPosition = newDockPosition
            coordinator?.notifyDockPositionChanged(newPosition: newDockPosition)
        }

        // Check if dock size changed (refresh indicator position for auto-size)
        if newDockSize != lastKnownDockSize {
            lastKnownDockSize = newDockSize
            coordinator?.notifyDockItemsChanged()
        }
    }

    /// Returns the current dock position
    func getCurrentDockPosition() -> DockPosition {
        lastKnownDockPosition
    }
}
