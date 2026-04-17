import Defaults
import SwiftUI

struct WidgetHoverContainer<Content: View>: View {
    let appName: String
    let bestGuessMonitor: NSScreen
    let dockPosition: DockPosition
    let dockItemElement: AXUIElement?
    let isPinnedMode: Bool
    let appIcon: NSImage?
    let hoveringAppIcon: Bool
    let highlightColor: Color?
    let backgroundAppearance: BackgroundAppearance
    let content: Content

    @Default(.showAppName) private var showAppTitleData
    @Default(.appNameStyle) private var appNameStyle

    init(
        appName: String,
        bestGuessMonitor: NSScreen,
        dockPosition: DockPosition,
        dockItemElement: AXUIElement?,
        isPinnedMode: Bool,
        appIcon: NSImage?,
        hoveringAppIcon: Bool,
        highlightColor: Color? = nil,
        backgroundAppearance: BackgroundAppearance,
        @ViewBuilder content: () -> Content
    ) {
        self.appName = appName
        self.bestGuessMonitor = bestGuessMonitor
        self.dockPosition = dockPosition
        self.dockItemElement = dockItemElement
        self.isPinnedMode = isPinnedMode
        self.appIcon = appIcon
        self.hoveringAppIcon = hoveringAppIcon
        self.highlightColor = highlightColor
        self.backgroundAppearance = backgroundAppearance
        self.content = content()
    }

    var body: some View {
        if isPinnedMode {
            pinnedContent
        } else {
            regularContent
        }
    }

    private var appTitleOverlay: some View {
        SharedHoverAppTitle(
            appName: appName,
            appIcon: appIcon,
            hoveringAppIcon: hoveringAppIcon,
            backgroundAppearance: backgroundAppearance
        )
    }

    private var regularContent: some View {
        BaseHoverContainer(
            bestGuessMonitor: bestGuessMonitor,
            mockPreviewActive: false,
            content: {
                VStack(spacing: 0) {
                    content
                }
                .padding(.top, (appNameStyle == .default && showAppTitleData) ? 25 : 0)
                .overlay(alignment: .topLeading) {
                    appTitleOverlay
                }
                .padding(.top, (appNameStyle == .popover && showAppTitleData) ? 30 : 0)
                .overlay {
                    if dockPosition != .cmdTab {
                        WindowDismissalContainer(
                            appName: appName,
                            bestGuessMonitor: bestGuessMonitor,
                            dockPosition: dockPosition,
                            dockItemElement: dockItemElement,
                            minimizeAllWindowsCallback: { _ in }
                        )
                        .allowsHitTesting(false)
                    }
                }
            },
            highlightColor: highlightColor,
            isWidget: true,
            backgroundAppearance: backgroundAppearance
        )
    }

    private var pinnedContent: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.top, (appNameStyle == .default && showAppTitleData) ? 25 : 0)
        .overlay(alignment: .topLeading) {
            appTitleOverlay
        }
        .background {
            BlurView(cornerRadius: CardRadius.container, appearance: backgroundAppearance)
        }
        .clipShape(RoundedRectangle(cornerRadius: CardRadius.container, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CardRadius.container, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.19), lineWidth: 1.75)
        }
        .padding(HoverContainerPadding.dockStyleOuter)
        .padding(.top, (appNameStyle == .popover && showAppTitleData) ? 30 : 0)
    }
}
