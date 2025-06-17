import SwiftUI

struct CalendarSkeleton: View {
    let isEmbedded: Bool
    let uniformCardRadius: Bool

    var body: some View {
        if isEmbedded {
            embeddedSkeleton()
        } else {
            fullSkeleton()
        }
    }

    @ViewBuilder
    private func embeddedSkeleton() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(CalendarLayout.skeletonOpacity))
                .frame(width: 80, height: 12)

            VStack(alignment: .leading, spacing: CalendarLayout.embeddedEventRowSpacing) {
                ForEach(0 ..< 2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(CalendarLayout.skeletonOpacity * 0.5))
                        .frame(height: CalendarLayout.embeddedEventHeight)
                }
            }
        }
        .glintPlaceholder()
    }

    @ViewBuilder
    private func fullSkeleton() -> some View {
        VStack(alignment: .leading, spacing: CalendarLayout.sectionSpacing + 8) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(CalendarLayout.skeletonOpacity))
                .frame(width: 120, height: 24)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: CalendarLayout.eventRowSpacing) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primary.opacity(CalendarLayout.skeletonOpacity * 0.5))
                        .frame(height: 70)
                        .overlay(alignment: .leading) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(CalendarLayout.skeletonOpacity))
                                    .frame(width: 6, height: 50)
                                    .padding(.leading, 12)

                                VStack(alignment: .leading, spacing: 6) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.primary.opacity(CalendarLayout.skeletonOpacity))
                                        .frame(height: 16)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.primary.opacity(CalendarLayout.skeletonOpacity))
                                        .frame(height: 12)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.primary.opacity(CalendarLayout.skeletonOpacity))
                                        .frame(width: 75, height: 10)
                                }
                            }
                            .padding(.trailing, 4)
                        }
                }
            }
        }
        .glintPlaceholder()
    }
}
