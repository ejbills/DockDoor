
import SwiftUI

struct CalendarEmptyState: View {
    let isEmbedded: Bool

    var body: some View {
        if isEmbedded {
            embeddedEmptyState()
        } else {
            fullEmptyState()
        }
    }

    @ViewBuilder
    private func embeddedEmptyState() -> some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("No events today")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func fullEmptyState() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.largeTitle)
                .fontWeight(.light)
                .imageScale(.medium)

            Text("No events scheduled for today!")
                .font(.headline)

            Text("Enjoy your free day or add some events to your calendar.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .shadow(radius: 2)
    }
}
