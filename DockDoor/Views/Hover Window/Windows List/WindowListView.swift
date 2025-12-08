import Defaults
import SwiftUI

struct WindowListView: View {
    let windows: [WindowInfo]
    let filteredIndices: [Int]
    let currentIndex: Int
    let onWindowTap: (() -> Void)?
    let handleWindowAction: (WindowAction, Int) -> Void
    let onHoverIndexChange: ((Int?) -> Void)?

    @Default(.showAnimations) var showAnimations
    @Default(.scrollToMouseHoverInSwitcher) var scrollToMouseHoverInSwitcher
    @Default(.uniformCardRadius) var uniformCardRadius

    var body: some View {
        VStack(spacing: 2) {
            ForEach(filteredIndices, id: \.self) { index in
                if index < windows.count {
                    WindowListItemView(
                        windowInfo: windows[index],
                        index: index,
                        isSelected: index == currentIndex,
                        onTap: onWindowTap,
                        handleWindowAction: { action in
                            handleWindowAction(action, index)
                        },
                        onHoverIndexChange: { hoveredIndex in
                            if let hoveredIndex, scrollToMouseHoverInSwitcher {
                                onHoverIndexChange?(hoveredIndex)
                            } else if hoveredIndex == nil {
                                onHoverIndexChange?(nil)
                            }
                        }
                    )
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(minWidth: 300, maxWidth: 600)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            BlurView(variant: 18)
                .clipShape(RoundedRectangle(cornerRadius: uniformCardRadius ? 12 : 0, style: .continuous))
        }
    }
}
