
import SwiftUI

struct CalendarEventRow: View {
    let event: DailyCalendarInfo.Event
    let isEmbedded: Bool

    var body: some View {
        if isEmbedded {
            embeddedEventRow()
        } else {
            fullEventRow()
        }
    }

    @ViewBuilder
    private func embeddedEventRow() -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(dateIntervalString(for: event))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let location = event.location {
                Text(location)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: CalendarLayout.embeddedEventHeight, alignment: .leading)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func fullEventRow() -> some View {
        let cornerRadius = 16.0

        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(dateIntervalString(for: event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let location = event.location {
                HStack(spacing: 3) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .background(Color.gray.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
    }

    private func dateIntervalString(for event: DailyCalendarInfo.Event) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: event.startDate, to: event.endDate)
    }
}
