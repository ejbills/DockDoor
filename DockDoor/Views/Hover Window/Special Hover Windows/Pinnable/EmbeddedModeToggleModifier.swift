import SwiftUI

struct EmbeddedModeToggleModifier: ViewModifier {
    @Binding var forceEmbeddedMode: Bool
    @State private var hoveringToggleButton: Bool = false
    @State private var originalSize: CGSize = .zero
    @State private var hasTransitioned: Bool = false
    let isPinnedMode: Bool
    let effectiveEmbeddedMode: Bool

    private enum Layout {
        static let toggleButtonSize: CGFloat = 24
        static let toggleHoverAreaSize: CGFloat = 50
    }

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear.onAppear {
                        if originalSize == .zero, !hasTransitioned {
                            originalSize = geometry.size
                        }
                    }
                    .onChange(of: geometry.size) { newSize in
                        if !hasTransitioned, originalSize == .zero {
                            originalSize = newSize
                        }
                    }
                }
            )
            .frame(
                width: (!effectiveEmbeddedMode && hasTransitioned && originalSize != .zero) ? originalSize.width : nil,
                height: (!effectiveEmbeddedMode && hasTransitioned && originalSize != .zero) ? originalSize.height : nil
            )
            .overlay(alignment: .topTrailing) {
                if isPinnedMode || forceEmbeddedMode {
                    toggleButtonHoverArea()
                }
            }
            .onChange(of: forceEmbeddedMode) { _ in
                hasTransitioned = true
            }
    }

    @ViewBuilder
    private func toggleButtonHoverArea() -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: Layout.toggleHoverAreaSize, height: Layout.toggleHoverAreaSize)
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.smooth(duration: 0.125)) {
                        forceEmbeddedMode.toggle()
                    }
                } label: {
                    Image(systemName: effectiveEmbeddedMode ? "arrow.up.right.and.arrow.down.left" : "arrow.down.left.and.arrow.up.right")
                        .bold()
                        .foregroundStyle(.secondary)
                        .frame(width: Layout.toggleButtonSize, height: Layout.toggleButtonSize)
                        .background(
                            Circle()
                                .fill(.regularMaterial)
                                .opacity(0.8)
                        )
                        .shadow(radius: 2)
                }
                .buttonStyle(.plain)
                .padding(12)
                .opacity(hoveringToggleButton ? 1.0 : 0.0)
                .scaleEffect(hoveringToggleButton ? 1.0 : 0.85)
                .help(effectiveEmbeddedMode ? "Expand to full mode" : "Collapse to embedded mode")
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    hoveringToggleButton = hovering
                }
            }
    }
}

extension View {
    func embeddedModeToggle(forceEmbeddedMode: Binding<Bool>, isPinnedMode: Bool, effectiveEmbeddedMode: Bool) -> some View {
        modifier(EmbeddedModeToggleModifier(
            forceEmbeddedMode: forceEmbeddedMode,
            isPinnedMode: isPinnedMode,
            effectiveEmbeddedMode: effectiveEmbeddedMode
        ))
    }

    @ViewBuilder
    func conditionalEmbeddedModeToggle(isPinnedMode: Bool, forceEmbeddedMode: Binding<Bool>, effectiveEmbeddedMode: Bool) -> some View {
        if isPinnedMode {
            embeddedModeToggle(
                forceEmbeddedMode: forceEmbeddedMode,
                isPinnedMode: isPinnedMode,
                effectiveEmbeddedMode: effectiveEmbeddedMode
            )
        } else {
            self
        }
    }
}
