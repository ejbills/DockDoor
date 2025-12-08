import Defaults
import SwiftUI

struct WindowListItemView: View {
    let windowInfo: WindowInfo
    let index: Int
    let isSelected: Bool
    let onTap: (() -> Void)?
    let handleWindowAction: (WindowAction) -> Void
    let onHoverIndexChange: ((Int?) -> Void)?

    @Default(.selectionOpacity) var selectionOpacity
    @Default(.hoverHighlightColor) var hoverHighlightColor
    @Default(.showMinimizedHiddenLabels) var showMinimizedHiddenLabels
    @Default(.trafficLightButtonsVisibility) var trafficLightButtonsVisibility
    @Default(.windowSwitcherListFontSize) var fontSize
    @Default(.listViewShowAppName) var showAppName

    @State private var isHovering = false

    private var iconSize: CGFloat {
        // Scale icon proportionally with font size (base: 32px icon for 13pt font)
        (fontSize / 13) * 32
    }

    private var displayTitle: String {
        let appName = windowInfo.app.localizedName ?? "Unknown"
        let windowName = windowInfo.windowName ?? ""

        if !showAppName {
            // Only show window title (or app name if no window title)
            return windowName.isEmpty ? appName : windowName
        }

        if windowName.isEmpty || windowName == appName {
            return appName
        }
        return "\(appName) - \(windowName)"
    }

    private var isInactiveWindow: Bool {
        (windowInfo.isMinimized || windowInfo.isHidden) && showMinimizedHiddenLabels
    }

    var body: some View {
        HStack(spacing: 12) {
            // App Icon
            if let appIcon = windowInfo.app.icon {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(.secondary)
            }

            // Window Title
            Text(displayTitle)
                .font(.system(size: fontSize))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isInactiveWindow ? .secondary : .primary)

            Spacer()

            // Status label for minimized/hidden windows
            if isInactiveWindow {
                Text(windowInfo.isMinimized ? "Minimized" : "Hidden")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }

            // Traffic light buttons on hover
            if isHovering || isSelected,
               windowInfo.closeButton != nil,
               !windowInfo.isMinimized,
               !windowInfo.isHidden,
               trafficLightButtonsVisibility != .never
            {
                TrafficLightButtons(
                    displayMode: .fullOpacityOnPreviewHover,
                    hoveringOverParentWindow: true,
                    onWindowAction: handleWindowAction,
                    pillStyling: true,
                    mockPreviewActive: false
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected || isHovering {
                let highlightColor = hoverHighlightColor ?? Color(nsColor: .controlAccentColor)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(highlightColor.opacity(selectionOpacity))
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
            onHoverIndexChange?(hovering ? index : nil)
        }
        .onTapGesture {
            handleWindowTap()
        }
        .contextMenu {
            if windowInfo.closeButton != nil {
                Button(action: { handleWindowAction(.minimize) }) {
                    if windowInfo.isMinimized {
                        Label("Un-minimize", systemImage: "arrow.up.left.and.arrow.down.right.square")
                    } else {
                        Label("Minimize", systemImage: "minus.square")
                    }
                }

                Button(action: { handleWindowAction(.toggleFullScreen) }) {
                    Label("Toggle Full Screen", systemImage: "arrow.up.left.and.arrow.down.right.square")
                }

                Divider()

                Button(action: { handleWindowAction(.close) }) {
                    Label("Close", systemImage: "xmark.square")
                }

                Button(role: .destructive, action: { handleWindowAction(.quit) }) {
                    if NSEvent.modifierFlags.contains(.option) {
                        Label("Force Quit", systemImage: "power")
                    } else {
                        Label("Quit", systemImage: "minus.square.fill")
                    }
                }
            }
        }
    }

    private func handleWindowTap() {
        if windowInfo.isMinimized {
            handleWindowAction(.minimize)
        } else if windowInfo.isHidden {
            handleWindowAction(.hide)
        } else {
            windowInfo.bringToFront()
            onTap?()
        }
    }
}
