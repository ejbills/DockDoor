import AppKit
import Defaults
import EventKit
import os.log
import SwiftUI

enum CalendarLayout {
    static let containerSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 12
    static let eventRowSpacing: CGFloat = 10
    static let skeletonOpacity: Double = 0.25
    static let embeddedEventRowSpacing: CGFloat = 6
    static let embeddedEventHeight: CGFloat = 40
}

struct CalendarView: View {
    @StateObject private var calendarInfo = DailyCalendarInfo()
    let appName: String
    let bundleIdentifier: String
    let dockPosition: DockPosition
    let bestGuessMonitor: NSScreen
    let isEmbeddedMode: Bool
    let isPinnedMode: Bool
    let idealWidth: CGFloat?

    @Default(.uniformCardRadius) private var uniformCardRadius

    @State private var appIcon: NSImage? = nil
    @State private var hoveringAppIcon = false
    @State private var hoveringWindowTitle = false

    init(appName: String,
         bundleIdentifier: String,
         dockPosition: DockPosition,
         bestGuessMonitor: NSScreen,
         isEmbeddedMode: Bool = false,
         isPinnedMode: Bool = false,
         idealWidth: CGFloat? = nil)
    {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.dockPosition = dockPosition
        self.bestGuessMonitor = bestGuessMonitor
        self.isEmbeddedMode = isEmbeddedMode
        self.isPinnedMode = isPinnedMode
        self.idealWidth = idealWidth
    }

    var body: some View {
        Group {
            if isEmbeddedMode {
                CalendarEmbeddedView(
                    calendarInfo: calendarInfo,
                    uniformCardRadius: uniformCardRadius,
                    idealWidth: idealWidth
                )
            } else {
                CalendarFullView(
                    calendarInfo: calendarInfo,
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    dockPosition: dockPosition,
                    bestGuessMonitor: bestGuessMonitor,
                    isPinnedMode: isPinnedMode,
                    appIcon: appIcon,
                    hoveringAppIcon: hoveringAppIcon,
                    hoveringWindowTitle: hoveringWindowTitle
                )
            }
        }
        .onAppear {
            loadAppIcon()
        }
    }

    private func loadAppIcon() {
        if let icon = SharedHoverUtils.loadAppIcon(for: bundleIdentifier) {
            DispatchQueue.main.async {
                if appIcon != icon { appIcon = icon }
            }
        } else if appIcon != nil {
            DispatchQueue.main.async { appIcon = nil }
        }
    }
}
