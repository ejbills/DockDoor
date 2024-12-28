import SwiftUI

struct DynStack<C: View>: View {
    var direction: Axis
    var spacing: Double
    var alignment: Alignment
    @ViewBuilder var content: () -> C

    init(
        direction: Axis,
        spacing: Double = 0,
        alignment: Alignment = .topLeading,
        @ViewBuilder content: @escaping () -> C
    ) {
        self.direction = direction
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        if direction == .vertical {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
            .frame(alignment: alignment)
        } else {
            HStack(alignment: .top, spacing: spacing) {
                content()
            }
            .frame(alignment: alignment)
        }
    }
}
