import Defaults
import SwiftUI

/// A grey caption under a row, with the full text in an ⓘ popover.
/// "Show setting descriptions" hides the caption but keeps the ⓘ.
struct SettingsAnnotationModifier: ViewModifier {
    let summary: Text
    let more: LocalizedStringKey?
    @Default(.showSettingsDescriptions) private var showDescriptions
    @State private var isShowingMore = false

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            content

            if showDescriptions {
                HStack(alignment: .top, spacing: 4) {
                    summary
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)

                    if let more {
                        Button {
                            isShowingMore = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $isShowingMore, arrowEdge: .bottom) {
                            Text(more)
                                .font(.footnote)
                                .multilineTextAlignment(.leading)
                                .padding(12)
                                .frame(width: 300, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func settingsAnnotation(_ summary: LocalizedStringKey, more: LocalizedStringKey? = nil) -> some View {
        modifier(SettingsAnnotationModifier(summary: Text(summary), more: more))
    }

    func settingsAnnotation(verbatim summary: String) -> some View {
        modifier(SettingsAnnotationModifier(summary: Text(verbatim: summary), more: nil))
    }
}
