
import SwiftUI

struct CalendarContentView: View {
    @ObservedObject var calendarInfo: DailyCalendarInfo

    var body: some View {
        let currentEventAuth = calendarInfo.eventAuthStatus
        let isLoadingCalendar = currentEventAuth == .notDetermined

        ScrollView(.vertical, showsIndicators: false) {
            if isLoadingCalendar {
                VStack {
                    CalendarSkeleton(isEmbedded: false, uniformCardRadius: false)
                }
                .frame(maxWidth: .infinity)
            } else if currentEventAuth == .denied || currentEventAuth == .restricted {
                VStack {
                    CalendarPermissionView(isEmbedded: false)
                }
                .frame(maxWidth: .infinity)
            } else if currentEventAuth == .authorized {
                VStack(alignment: .leading, spacing: CalendarLayout.sectionSpacing) {
                    if !calendarInfo.events.isEmpty {
                        Text("Today")
                            .font(.title3)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: CalendarLayout.eventRowSpacing) {
                            ForEach(calendarInfo.events) { event in
                                CalendarEventRow(event: event, isEmbedded: false)
                            }
                        }
                    } else {
                        CalendarEmptyState(isEmbedded: false)
                    }
                }
                .frame(minHeight: 175, alignment: calendarInfo.events.isEmpty ? .center : .topLeading)
            }
        }
        .globalPadding(20)
    }
}
