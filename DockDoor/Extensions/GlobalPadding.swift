import Defaults
import SwiftUI

extension View {
    /// Global padding that applies the globalPaddingMultiplier to all padding values
    func globalPadding(_ insets: EdgeInsets) -> some View {
        let multiplier = Defaults[.globalPaddingMultiplier]
        return padding(EdgeInsets(
            top: insets.top * multiplier,
            leading: insets.leading * multiplier,
            bottom: insets.bottom * multiplier,
            trailing: insets.trailing * multiplier
        ))
    }

    /// Global padding that applies the globalPaddingMultiplier to the specified edges
    func globalPadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        let multiplier = Defaults[.globalPaddingMultiplier]
        let adjustedLength = length.map { $0 * multiplier }
        return padding(edges, adjustedLength)
    }

    /// Global padding that applies the globalPaddingMultiplier to a specific length
    func globalPadding(_ length: CGFloat) -> some View {
        let multiplier = Defaults[.globalPaddingMultiplier]
        return padding(length * multiplier)
    }

    /// Global padding with default system padding (approximately 16 points)
    func globalPadding() -> some View {
        let multiplier = Defaults[.globalPaddingMultiplier]
        return padding(16 * multiplier)
    }
}

// MARK: - Reactive Global Padding

// These variants automatically update when the global multiplier changes

extension View {
    /// Reactive global padding that updates when globalPaddingMultiplier changes
    /// This version observes the default value and updates the view accordingly
    func reactiveGlobalPadding(_ insets: EdgeInsets) -> some View {
        GlobalPaddingView(content: self, insets: insets)
    }

    /// Reactive global padding that updates when globalPaddingMultiplier changes
    func reactiveGlobalPadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        GlobalPaddingView(content: self, edges: edges, length: length)
    }

    /// Reactive global padding that updates when globalPaddingMultiplier changes
    func reactiveGlobalPadding(_ length: CGFloat) -> some View {
        GlobalPaddingView(content: self, length: length)
    }

    /// Reactive global padding with default system padding
    func reactiveGlobalPadding() -> some View {
        GlobalPaddingView(content: self, length: 16)
    }
}

// MARK: - Supporting View for Reactive Padding

private struct GlobalPaddingView<Content: View>: View {
    let content: Content
    var insets: EdgeInsets?
    var edges: Edge.Set?
    var length: CGFloat?

    @Default(.globalPaddingMultiplier) private var globalPaddingMultiplier

    init(content: Content, insets: EdgeInsets) {
        self.content = content
        self.insets = insets
    }

    init(content: Content, edges: Edge.Set = .all, length: CGFloat? = nil) {
        self.content = content
        self.edges = edges
        self.length = length
    }

    init(content: Content, length: CGFloat) {
        self.content = content
        self.length = length
    }

    var body: some View {
        if let insets {
            content.padding(EdgeInsets(
                top: insets.top * globalPaddingMultiplier,
                leading: insets.leading * globalPaddingMultiplier,
                bottom: insets.bottom * globalPaddingMultiplier,
                trailing: insets.trailing * globalPaddingMultiplier
            ))
        } else if let edges {
            let adjustedLength = length.map { $0 * globalPaddingMultiplier }
            content.padding(edges, adjustedLength)
        } else if let length {
            content.padding(length * globalPaddingMultiplier)
        } else {
            content.padding(16 * globalPaddingMultiplier) // Default SwiftUI padding is ~16pts
        }
    }
}

// MARK: - Convenience Extensions for Common Patterns

extension View {
    /// Applies global padding to horizontal edges only
    func globalPaddingHorizontal(_ length: CGFloat = 16) -> some View {
        globalPadding(.horizontal, length)
    }

    /// Applies global padding to vertical edges only
    func globalPaddingVertical(_ length: CGFloat = 16) -> some View {
        globalPadding(.vertical, length)
    }

    /// Applies global padding to top edge only
    func globalPaddingTop(_ length: CGFloat = 16) -> some View {
        globalPadding(.top, length)
    }

    /// Applies global padding to bottom edge only
    func globalPaddingBottom(_ length: CGFloat = 16) -> some View {
        globalPadding(.bottom, length)
    }

    /// Applies global padding to leading edge only
    func globalPaddingLeading(_ length: CGFloat = 16) -> some View {
        globalPadding(.leading, length)
    }

    /// Applies global padding to trailing edge only
    func globalPaddingTrailing(_ length: CGFloat = 16) -> some View {
        globalPadding(.trailing, length)
    }
}
