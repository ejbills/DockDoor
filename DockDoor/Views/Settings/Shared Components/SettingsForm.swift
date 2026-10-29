import SwiftUI

struct SettingsFormView<Content: View, Header: View>: View {
    @Environment(\.settingsScrollTarget) private var scrollTarget
    let content: Content
    let header: Header

    init(@ViewBuilder content: () -> Content, @ViewBuilder pinnedHeader: () -> Header) {
        self.content = content()
        header = pinnedHeader()
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                content
            }
            .formStyle(.grouped)
            .modifier(SoftTopScrollEdge())
            .safeAreaInset(edge: .top, spacing: 0) {
                if Header.self != EmptyView.self {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 6)
                        .background(Color(nsColor: .windowBackgroundColor))
                }
            }
            .onChange(of: scrollTarget) { target in
                guard let target else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
            .onAppear {
                guard let target = scrollTarget else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
        .frame(minWidth: 650, idealWidth: 700, minHeight: 650)
    }
}

extension SettingsFormView where Header == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content, pinnedHeader: { EmptyView() })
    }
}

private struct SoftTopScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    var footer: LocalizedStringKey?
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, footer: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        Section {
            content
        } header: {
            Text(title)
        } footer: {
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Glass on macOS 26, bordered before.
struct SettingsButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            Button(configuration).buttonStyle(.glass)
        } else {
            Button(configuration).buttonStyle(.bordered)
        }
    }
}

extension PrimitiveButtonStyle where Self == SettingsButtonStyle {
    static var settings: SettingsButtonStyle {
        SettingsButtonStyle()
    }
}

/// Hidden until modified so rows keep their width.
struct SettingsResetButton: View {
    let isModified: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Reset to default")
        .accessibilityLabel("Reset to default")
        .opacity(isModified ? 1 : 0)
        .disabled(!isModified)
    }
}
