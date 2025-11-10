import SwiftUI

/// Bridge view that renders the existing CalendarView as a native widget.
@MainActor
struct CalendarWidgetView: View {
    let context: [String: String]
    let appName: String
    let bundleIdentifier: String
    let dockPosition: DockPosition
    let screen: NSScreen
    let mode: WidgetMode

    @StateObject private var calendarInfo = DailyCalendarInfo()

    init(
        context: [String: String],
        appName: String,
        bundleIdentifier: String,
        dockPosition: DockPosition,
        screen: NSScreen,
        mode: WidgetMode
    ) {
        self.context = context
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.dockPosition = dockPosition
        self.screen = screen
        self.mode = mode
    }

    var body: some View {
        let isEmbedded = (mode == .embedded)
        CalendarView(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            dockPosition: dockPosition,
            bestGuessMonitor: screen,
            dockItemElement: nil,
            isEmbeddedMode: isEmbedded,
            isPinnedMode: false,
            idealWidth: isEmbedded ? 200 : nil,
            calendarInfo: calendarInfo
        )
    }
}
