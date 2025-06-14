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
            .onChange(of: isPinned) { newValue in
                let alreadyPinned = SharedPreviewWindowCoordinator.activeInstance?.isPinned(bundleIdentifier: bundleIdentifier, type: pinnableType) ?? false

                if newValue, !alreadyPinned {
                    // Create pinned window via coordinator only if it doesn't exist
                    SharedPreviewWindowCoordinator.activeInstance?.createPinnedWindow(
                        appName: appName,
                        bundleIdentifier: bundleIdentifier,
                        type: pinnableType
                    )
                    // Hide original window
                    SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
                } else if !newValue, alreadyPinned {
                    // Close pinned window via coordinator only if it exists
                    let key = "\(bundleIdentifier)-\(pinnableType.rawValue)"
                    SharedPreviewWindowCoordinator.activeInstance?.closePinnedWindow(key: key)
                }
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
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPinned = false
                    let key = "\(bundleIdentifier)-\(pinnableType.rawValue)"
                    SharedPreviewWindowCoordinator.activeInstance?.closePinnedWindow(key: key)
                    SharedPreviewWindowCoordinator.activeInstance?.hideWindow()
                }
            }
        } else {
            Button("Pin to Screen") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPinned = true
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
