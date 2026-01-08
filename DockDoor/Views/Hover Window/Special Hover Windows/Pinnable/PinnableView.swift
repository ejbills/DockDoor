import Defaults
import Foundation
import SwiftUI

/// Types of views that can be pinned
enum PinnableViewType: String, CaseIterable, Codable {
    case media
    case calendar

    var displayName: String {
        switch self {
        case .media:
            String(localized: "Media Controls", comment: "Pinnable view type name for media controls widget")
        case .calendar:
            String(localized: "Calendar", comment: "Pinnable view type name for calendar widget")
        }
    }
}

/// A view modifier that adds pinning functionality to special views like MediaControlsView and CalendarView
struct PinnableViewModifier: ViewModifier {
    let appName: String
    let bundleIdentifier: String
    let pinnableType: PinnableViewType

    @State private var isPinned: Bool = false
    @Default(.enablePinning) private var enablePinning

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .contextMenu {
                if enablePinning {
                    contextMenuContent
                }
            }
            .onAppear {
                updatePinnedState()
            }
    }

    private func updatePinnedState() {
        let newPinnedState = SharedPreviewWindowCoordinator.activeInstance?.isPinned(bundleIdentifier: bundleIdentifier, type: pinnableType) ?? false
        if isPinned != newPinnedState {
            isPinned = newPinnedState
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        let currentlyPinned = SharedPreviewWindowCoordinator.activeInstance?.isPinned(bundleIdentifier: bundleIdentifier, type: pinnableType) ?? false

        if currentlyPinned {
            Button("Unpin from Screen") {
                let key = "\(bundleIdentifier)-\(pinnableType.rawValue)"
                SharedPreviewWindowCoordinator.activeInstance?.closePinnedWindow(key: key)
                SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
            }
        } else {
            Section("Pin to Screen") {
                Button {
                    SharedPreviewWindowCoordinator.activeInstance?.createPinnedWindow(
                        appName: appName,
                        bundleIdentifier: bundleIdentifier,
                        type: pinnableType,
                        isEmbedded: false
                    )
                    SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
                } label: {
                    Label("Full Mode", systemImage: "rectangle.expand.vertical")
                }

                Button {
                    SharedPreviewWindowCoordinator.activeInstance?.createPinnedWindow(
                        appName: appName,
                        bundleIdentifier: bundleIdentifier,
                        type: pinnableType,
                        isEmbedded: true
                    )
                    SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
                } label: {
                    Label("Compact Mode", systemImage: "rectangle.compress.vertical")
                }
            }
        }
    }
}

/// Extension to make it easy to apply the pinnable modifier
extension View {
    func pinnable(appName: String, bundleIdentifier: String, type: PinnableViewType) -> some View {
        modifier(PinnableViewModifier(appName: appName, bundleIdentifier: bundleIdentifier, pinnableType: type))
    }
}

/// View modifier for pinned windows with options to switch mode and close
private struct PinnableDisabledModifier: ViewModifier {
    let key: String
    let currentType: PinnableViewType
    let isEmbedded: Bool

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .contextMenu {
                Button {
                    SharedPreviewWindowCoordinator.activeInstance?.togglePinnedWindowMode(key: key)
                } label: {
                    if isEmbedded {
                        Label("Switch to Full", systemImage: "rectangle.expand.vertical")
                    } else {
                        Label("Switch to Compact", systemImage: "rectangle.compress.vertical")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    SharedPreviewWindowCoordinator.activeInstance?.closePinnedWindow(key: key)
                } label: {
                    Label("Close", systemImage: "xmark.circle")
                }
            }
    }
}

extension View {
    func pinnableDisabled(key: String, type: PinnableViewType, isEmbedded: Bool) -> some View {
        modifier(PinnableDisabledModifier(key: key, currentType: type, isEmbedded: isEmbedded))
    }
}
