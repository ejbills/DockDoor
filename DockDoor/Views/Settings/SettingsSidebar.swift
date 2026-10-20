import SwiftUI

enum SettingsSidebarRow: Identifiable, Equatable {
    case heading(SettingsTab.Section)
    case tab(SettingsTab)

    var id: String {
        switch self {
        case let .heading(section): "heading:\(section)"
        case let .tab(tab): tab.rawValue
        }
    }

    static let all: [SettingsSidebarRow] = [.tab(.general)] + SettingsTab.Section.allCases.flatMap { section in
        [.heading(section)] + SettingsTab.tabs(in: section).map(SettingsSidebarRow.tab)
    }

    static let tabs: [SettingsTab] = all.compactMap {
        if case let .tab(tab) = $0 { return tab }
        return nil
    }

    static func tab(movingBy offset: Int, from current: SettingsTab) -> SettingsTab? {
        guard let index = tabs.firstIndex(of: current), tabs.indices.contains(index + offset) else { return nil }
        return tabs[index + offset]
    }
}

/// Rows of its own, not a List: List Sections crash AppKit on macOS 27.0 and 27.2
/// (a freed row view in sizeLastColumnToFit), and a List draws its own selection.
struct SettingsSidebar: View {
    @Binding var selectedTab: SettingsTab
    let isSearching: Bool
    let select: (SettingsTab) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(SettingsSidebarRow.all) { row in
                        switch row {
                        case let .heading(section):
                            Text(verbatim: section.localizedTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.top, 12)
                                .padding(.bottom, 4)
                                .padding(.leading, 8)
                        case let .tab(tab):
                            SettingsSidebarTabRow(tab: tab, isSelected: !isSearching && tab == selectedTab) {
                                select(tab)
                            }
                            .id(tab.rawValue)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .onChange(of: selectedTab) { tab in
                proxy.scrollTo(tab.rawValue)
            }
        }
        .modifier(SidebarScrollEdgeModifier())
        .focusable()
        .modifier(FocusEffectDisabledModifier())
        .onMoveCommand { direction in
            let offset = switch direction {
            case .up: -1
            case .down: 1
            default: 0
            }
            guard offset != 0, let tab = SettingsSidebarRow.tab(movingBy: offset, from: selectedTab) else { return }
            select(tab)
        }
    }
}

private struct SettingsSidebarTabRow: View {
    let tab: SettingsTab
    let isSelected: Bool
    let select: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    private static let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)

    var body: some View {
        Button(action: select) {
            Label {
                Text(verbatim: tab.localizedTitle)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            } icon: {
                Image(systemName: tab.systemImage)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .background {
                if isSelected {
                    Self.shape
                        .fill(.quaternary.opacity(reduceTransparency ? 0.65 : 0.45))
                        .overlay(Self.shape.fill(Color.accentColor.opacity(reduceTransparency ? 0.35 : 0.22)))
                        .overlay(Self.shape.strokeBorder(Color.accentColor.opacity(reduceTransparency ? 0.42 : 0.28), lineWidth: 1))
                }
            }
            .overlay {
                if isSelected, differentiateWithoutColor {
                    Self.shape.strokeBorder(.primary, lineWidth: 1.5)
                }
            }
            .contentShape(Self.shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SidebarScrollEdgeModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

private struct FocusEffectDisabledModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.focusEffectDisabled()
        } else {
            content
        }
    }
}
