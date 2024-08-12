import SwiftUI

struct DynStack<C: View>: View {
    var direction: Axis
    var spacing: Double
    @ViewBuilder var content: () -> C
    var body: some View {
        if direction == .vertical {
            VStack(spacing: spacing) {
                content()
            }
        } else {
            HStack(spacing: spacing) {
                content()
            }
        }
    }
}
