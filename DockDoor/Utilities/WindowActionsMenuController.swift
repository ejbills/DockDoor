import AppKit

final class WindowActionsMenuController: NSObject, NSMenuDelegate {
    let menu: NSMenu

    private struct Request {
        let window: WindowInfo
        let action: WindowAction
    }

    override init() {
        menu = NSMenu(title: String(localized: "Window Actions", comment: "Menu bar submenu title"))
        super.init()
        menu.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let windows = WindowUtil.getAllWindowsIgnoringSwitcherFilters()
        guard !windows.isEmpty else {
            let empty = NSMenuItem(title: String(localized: "No Windows", comment: "Empty window actions menu"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        let grouped = Dictionary(grouping: windows, by: { $0.app.processIdentifier })
        let sortedApps = grouped.sorted { lhs, rhs in
            let lhsName = lhs.value.first?.app.localizedName ?? ""
            let rhsName = rhs.value.first?.app.localizedName ?? ""
            return lhsName.localizedStandardCompare(rhsName) == .orderedAscending
        }

        for (_, appWindows) in sortedApps {
            guard let app = appWindows.first?.app else { continue }
            let appItem = NSMenuItem(title: app.localizedName ?? String(localized: "Unknown App", comment: "Fallback app name"), action: nil, keyEquivalent: "")
            appItem.image = app.icon?.resizedToFit(in: NSSize(width: 16, height: 16))

            let appSubmenu = NSMenu()
            for window in appWindows {
                let windowItem = NSMenuItem(title: title(for: window), action: nil, keyEquivalent: "")
                windowItem.submenu = actionsMenu(for: window)
                appSubmenu.addItem(windowItem)
            }
            appItem.submenu = appSubmenu
            menu.addItem(appItem)
        }
    }

    private func title(for window: WindowInfo) -> String {
        if window.isWindowlessApp {
            return String(localized: "No Open Windows", comment: "Window actions entry for an app with no windows")
        }
        let name = window.windowName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = name.isEmpty ? (window.app.localizedName ?? String(localized: "Untitled", comment: "Fallback window title")) : name
        var decorated = base
        if window.isMinimized {
            decorated += String(localized: " (minimized)", comment: "Suffix for a minimized window in the actions menu")
        } else if window.isHidden {
            decorated += String(localized: " (hidden)", comment: "Suffix for a hidden window in the actions menu")
        }
        return decorated
    }

    private func actionsMenu(for window: WindowInfo) -> NSMenu {
        let submenu = NSMenu()
        let groups = WindowAction.availableGroups(for: window)

        for (index, entry) in groups.enumerated() {
            if index > 0 {
                submenu.addItem(.separator())
            }
            for action in entry.actions {
                let item = NSMenuItem(title: action.menuTitle(for: window), action: #selector(performAction(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = Request(window: window, action: action)
                item.image = NSImage(systemSymbolName: action.menuIcon(for: window), accessibilityDescription: nil)
                submenu.addItem(item)
            }
        }
        return submenu
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let request = sender.representedObject as? Request else { return }
        _ = request.action.perform(on: request.window)
    }
}
