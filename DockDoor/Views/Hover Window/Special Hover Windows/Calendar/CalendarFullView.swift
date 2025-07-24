import Defaults
import SwiftUI

struct CalendarFullView: View {
    @ObservedObject var calendarInfo: DailyCalendarInfo
    let appName: String
    let bundleIdentifier: String
    let dockPosition: DockPosition
    let bestGuessMonitor: NSScreen
    let isPinnedMode: Bool
    let appIcon: NSImage?
    let hoveringAppIcon: Bool
    let hoveringWindowTitle: Bool

    @Default(.showAppName) private var showAppTitleData
    @Default(.appNameStyle) private var appNameStyle

    var body: some View {
        Group {
            if isPinnedMode {
                pinnedContent()
            } else {
                regularContent()
            }
        }
    }

    @ViewBuilder
    private func regularContent() -> some View {
        BaseHoverContainer(
            bestGuessMonitor: bestGuessMonitor,
            mockPreviewActive: false,
            content: {
                VStack(spacing: 0) {
                    CalendarContentView(calendarInfo: calendarInfo)
                }
                .padding(.top, (appNameStyle == .default && showAppTitleData) ? 25 : 0)
                .overlay(alignment: .topLeading) {
                    SharedHoverAppTitle(
                        appName: appName,
                        appIcon: appIcon,
                        hoveringAppIcon: hoveringAppIcon
                    )
                    .padding([.top, .leading], 4)
                }
                .dockStyle()
                .padding(.top, (appNameStyle == .popover && showAppTitleData) ? 30 : 0)
                .overlay {
                    WindowDismissalContainer(appName: appName,
                                             bestGuessMonitor: bestGuessMonitor,
                                             dockPosition: dockPosition,
                                             minimizeAllWindowsCallback: { _ in })
                        .allowsHitTesting(false)
                }
            },
            highlightColor: nil,
            preventDockStyling: true
        )
        .pinnable(appName: appName, bundleIdentifier: bundleIdentifier, type: .calendar)
    }

    @ViewBuilder
    private func pinnedContent() -> some View {
        VStack(spacing: 0) {
            CalendarContentView(calendarInfo: calendarInfo)
        }
        .padding(.top, (appNameStyle == .default && showAppTitleData) ? 25 : 0)
        .overlay(alignment: .topLeading) {
            SharedHoverAppTitle(
                appName: appName,
                appIcon: appIcon,
                hoveringAppIcon: hoveringAppIcon
            )
            .padding([.top, .leading], 4)
        }
        .dockStyle()
        .padding(.top, (appNameStyle == .popover && showAppTitleData) ? 30 : 0)
    }
}
