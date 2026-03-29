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
            hoveringAppIcon: hoveringAppIcon,
            onTitleTap: {
                guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else { return }
                if app.isHidden { app.unhide() }
                app.activate(options: [.activateIgnoringOtherApps])
            }
        ) {
            CalendarContentView(calendarInfo: calendarInfo)
        }
        .if(!isPinnedMode) { view in
            view.pinnable(appName: appName, bundleIdentifier: bundleIdentifier, type: .calendar)
        }
    }
}
