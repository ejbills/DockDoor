import SwiftUI

struct ModifierKeyToggles: View {
    @Binding var modifierFlags: Int
    var compact = false
    // When set, an empty selection is allowed and shows these modifiers dimmed as inherited.
    var inheritedModifierFlags: Int?

    private var allowsEmpty: Bool { inheritedModifierFlags != nil }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            ForEach(ShortcutModifier.allCases) { modifier in
                toggle(for: modifier)
            }
        }
    }

    private func toggle(for modifier: ShortcutModifier) -> some View {
        let selected = ShortcutModifier.contained(in: modifierFlags)
        let isOn = selected.contains(modifier)
        let isInherited = selected.isEmpty && modifier.isContained(in: inheritedModifierFlags ?? 0)
        let isLastSelected = isOn && selected.count == 1 && !allowsEmpty

        return Button {
            guard !isLastSelected else { return }
            let newSelection = isOn ? selected.filter { $0 != modifier } : selected + [modifier]
            modifierFlags = ShortcutModifier.modifierFlags(for: newSelection)
        } label: {
            Text(compact ? modifier.symbol : "\(modifier.localizedName) \(modifier.symbol)")
                .font(.system(size: compact ? 13 : 12, weight: .medium))
                .foregroundColor(isOn ? .white : .primary)
                .frame(minWidth: compact ? 22 : nil)
                .padding(.horizontal, compact ? 4 : 10)
                .padding(.vertical, compact ? 2 : 4)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isOn ? Color.accentColor : isInherited ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.15))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isInherited ? String(localized: "\(modifier.localizedName), inherited from the main shortcut") : modifier.localizedName)
    }
}
