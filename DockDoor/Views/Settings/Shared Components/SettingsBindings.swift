import SwiftUI

/// One picker over the showAppName / appNameStyle / showAppIconOnly keys; each surface passes its own.
enum AppHeaderMode: String, CaseIterable, Identifiable {
    case hidden
    case iconOnly
    case nameAndIcon
    case shadowed
    case popover

    var id: Self {
        self
    }

    var localizedName: String {
        switch self {
        case .hidden: String(localized: "Hidden", comment: "App header option")
        case .iconOnly: String(localized: "Icon only", comment: "App header option")
        case .nameAndIcon: String(localized: "Name and icon", comment: "App header option")
        case .shadowed: String(localized: "Name and icon (shadowed)", comment: "App header option")
        case .popover: String(localized: "Popover", comment: "App header option")
        }
    }

    static func binding(
        showName: Binding<Bool>,
        showIconOnly: Binding<Bool>,
        style: Binding<AppNameStyle>
    ) -> Binding<AppHeaderMode> {
        Binding(
            get: {
                if !showName.wrappedValue {
                    return .hidden
                }
                if showIconOnly.wrappedValue {
                    return .iconOnly
                }
                switch style.wrappedValue {
                case .default: return .nameAndIcon
                case .shadowed: return .shadowed
                case .popover: return .popover
                }
            },
            set: { mode in
                switch mode {
                case .hidden:
                    showName.wrappedValue = false
                    showIconOnly.wrappedValue = false
                case .iconOnly:
                    showName.wrappedValue = true
                    showIconOnly.wrappedValue = true
                case .nameAndIcon, .shadowed, .popover:
                    showName.wrappedValue = true
                    showIconOnly.wrappedValue = false
                    style.wrappedValue = switch mode {
                    case .nameAndIcon: .default
                    case .shadowed: .shadowed
                    default: .popover
                    }
                }
            }
        )
    }
}

/// One picker over the showTitle and visibility keys.
enum WindowTitleMode: String, CaseIterable, Identifiable {
    case hidden
    case whenHoveringPreview
    case alwaysVisible

    var id: Self {
        self
    }

    var localizedName: String {
        switch self {
        case .hidden: String(localized: "Hidden", comment: "Window title visibility option")
        case .whenHoveringPreview: String(localized: "When hovering over the preview", comment: "Window title visibility option")
        case .alwaysVisible: String(localized: "Always visible", comment: "Window title visibility option")
        }
    }

    static func binding(
        showTitle: Binding<Bool>,
        visibility: Binding<WindowTitleVisibility>
    ) -> Binding<WindowTitleMode> {
        Binding(
            get: {
                guard showTitle.wrappedValue else { return .hidden }
                return visibility.wrappedValue == .alwaysVisible ? .alwaysVisible : .whenHoveringPreview
            },
            set: { mode in
                switch mode {
                case .hidden:
                    showTitle.wrappedValue = false
                case .whenHoveringPreview:
                    showTitle.wrappedValue = true
                    visibility.wrappedValue = .whenHoveringPreview
                case .alwaysVisible:
                    showTitle.wrappedValue = true
                    visibility.wrappedValue = .alwaysVisible
                }
            }
        )
    }
}
