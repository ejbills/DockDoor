import Foundation

/// Chooses which widgets to show for a given app and context.
struct WidgetOrchestrator {
    /// Basic policy: pick all matching widgets and separate by supported mode.
    /// Future policy can include ordering, feature flags, and fallbacks.
    func selectWidgets(for bundleId: String) -> WidgetSelection {
        let all = WidgetRegistry.matchingWidgets(for: bundleId)
        let embedded = all.filter { $0.modes.contains(.embedded) }
        let full = all.filter { $0.modes.contains(.full) }
        return WidgetSelection(embedded: embedded, full: full)
    }
}
