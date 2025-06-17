import Defaults
import SwiftUI

struct CalendarEmbeddedView: View {
    @ObservedObject var calendarInfo: DailyCalendarInfo
    let uniformCardRadius: Bool
    let idealWidth: CGFloat?

    @Environment(\.openURL) private var openURL

    var body: some View {
        let currentEventAuth = calendarInfo.eventAuthStatus
        let isLoadingCalendar = currentEventAuth == .notDetermined

        VStack(alignment: .leading, spacing: 8) {
            if isLoadingCalendar {
                CalendarSkeleton(isEmbedded: true, uniformCardRadius: uniformCardRadius)
            } else if currentEventAuth == .denied || currentEventAuth == .restricted {
                CalendarPermissionView(isEmbedded: true)
            } else if currentEventAuth == .authorized {
                if !calendarInfo.events.isEmpty {
                    VStack(alignment: .leading, spacing: CalendarLayout.embeddedEventRowSpacing) {
                        Text("Today")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        LazyVStack(alignment: .leading, spacing: CalendarLayout.embeddedEventRowSpacing) {
                            ForEach(calendarInfo.events.prefix(3)) { event in
                                CalendarEventRow(event: event, isEmbedded: true)
                            }

                            if calendarInfo.events.count > 3 {
                                Text("+\(calendarInfo.events.count - 3) more")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                            }
                        }
                    }
                } else {
                    CalendarEmptyState(isEmbedded: true)
                }
            }
        }
        .padding(12)
        .dockStyle()
        .frame(minWidth: idealWidth ?? 200, alignment: .center)
    }
}
