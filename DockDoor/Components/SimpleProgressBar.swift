import SwiftUI

struct SimpleProgressBar: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var barColor: Color = .accentColor
    var backgroundColor: Color = .primary.opacity(0.08)
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var isHovering = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: isHovering ? 8 : 6)
                    .fill(backgroundColor)
                    .frame(height: isHovering ? 8 : 6)
                    .animation(.smooth(duration: 0.15), value: isHovering)

                RoundedRectangle(cornerRadius: isHovering ? 8 : 6)
                    .fill(barColor)
                    .frame(width: progressWidth(geometry: geometry), height: isHovering ? 8 : 6)
                    .animation(.smooth(duration: 0.1), value: progressWidth(geometry: geometry))
                    .animation(.smooth(duration: 0.15), value: isHovering)

                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 20)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gestureValue in
                        if !isDragging {
                            isDragging = true
                            dragValue = ((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width
                        }

                        dragValue = max(0, min(geometry.size.width, gestureValue.location.x))
                        let percentage = dragValue / geometry.size.width
                        value = range.lowerBound + (range.upperBound - range.lowerBound) * percentage
                    }
                    .onEnded { gestureValue in
                        let percentage = max(0, min(1, gestureValue.location.x / geometry.size.width))
                        value = range.lowerBound + (range.upperBound - range.lowerBound) * percentage
                        isDragging = false
                    }
            )
            .onHover { hovering in
                withAnimation(.smooth(duration: 0.15)) {
                    isHovering = hovering
                }
            }
        }
    }

    private func progressWidth(geometry: GeometryProxy) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return max(0, min(geometry.size.width, geometry.size.width * Double(percentage)))
    }
}
