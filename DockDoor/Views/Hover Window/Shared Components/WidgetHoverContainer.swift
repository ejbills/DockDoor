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
            hoveringAppIcon: hoveringAppIcon
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
            isWidget: true
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
        .dockStyle()
        .padding(.top, (appNameStyle == .popover && showAppTitleData) ? 30 : 0)
    }
}
