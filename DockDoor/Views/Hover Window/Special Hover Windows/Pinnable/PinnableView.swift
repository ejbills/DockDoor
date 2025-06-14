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
            "Media Controls"
        case .calendar:
            "Calendar"
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
            Button("Unpin") {
                let key = "\(bundleIdentifier)-\(pinnableType.rawValue)"
                SharedPreviewWindowCoordinator.activeInstance?.closePinnedWindow(key: key)
                SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
            }
        } else {
            Button("Pin to Screen (Full)") {
                SharedPreviewWindowCoordinator.activeInstance?.createPinnedWindow(
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    type: pinnableType,
                    isEmbedded: false
                )
                SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
            }

            Button("Pin to Screen (Compact)") {
                SharedPreviewWindowCoordinator.activeInstance?.createPinnedWindow(
                    appName: appName,
                    bundleIdentifier: bundleIdentifier,
                    type: pinnableType,
                    isEmbedded: true
                )
                SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
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

/// View modifier for pinned windows (disables pinning, adds close option)
private struct PinnableDisabledModifier: ViewModifier {
    let key: String

    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button("Close") {
                    SharedPreviewWindowCoordinator.activeInstance?.closePinnedWindow(key: key)
                }
            }
    }
}

extension View {
    func pinnableDisabled(key: String) -> some View {
        modifier(PinnableDisabledModifier(key: key))
    }
}
