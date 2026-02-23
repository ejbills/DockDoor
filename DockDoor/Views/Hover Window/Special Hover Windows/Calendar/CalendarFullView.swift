import Defaults
import SwiftUI

struct CalendarFullView: View {
    @ObservedObject var calendarInfo: DailyCalendarInfo
    let appName: String
    let bundleIdentifier: String
    let dockPosition: DockPosition
    let bestGuessMonitor: NSScreen
    let dockItemElement: AXUIElement?
    let isPinnedMode: Bool
    let appIcon: NSImage?
    let hoveringAppIcon: Bool
    let hoveringWindowTitle: Bool

    @Default(.uniformCardRadius) private var uniformCardRadius

    var body: some View {
        WidgetHoverContainer(
            appName: appName,
            bestGuessMonitor: bestGuessMonitor,
            dockPosition: dockPosition,
            dockItemElement: dockItemElement,
            isPinnedMode: isPinnedMode,
            appIcon: appIcon,
            hoveringAppIcon: hoveringAppIcon
        ) {
            CalendarContentView(calendarInfo: calendarInfo)
        }
        .pinnable(appName: appName, bundleIdentifier: bundleIdentifier, type: .calendar)
    }
}
