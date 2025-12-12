import Defaults
import ScreenCaptureKit
import SwiftUI

struct TrafficLightButtons: View {
    @Environment(\.colorScheme) var colorScheme
    let displayMode: TrafficLightButtonsVisibility
    let hoveringOverParentWindow: Bool
    let onWindowAction: (WindowAction) -> Void
    let pillStyling: Bool
    let mockPreviewActive: Bool
    let enabledButtons: Set<WindowAction>
    let useMonochrome: Bool
    let disableButtonHoverEffects: Bool
    @State private var isHovering = false

    var body: some View {
        let monochromeFillColor = colorScheme == .dark ? Color.gray.darker(by: 0.075) : Color.white
        Group {
            if displayMode != .never {
                HStack(spacing: 6) {
                    if enabledButtons.contains(.quit) {
                        buttonFor(action: .quit, symbol: "power",
                                  color: useMonochrome ? .secondary : Color(hex: "290133"),
                                  fillColor: useMonochrome ? monochromeFillColor : .purple)
                    }
                    if enabledButtons.contains(.close) {
                        buttonFor(action: .close, symbol: "xmark",
                                  color: useMonochrome ? .secondary : Color(hex: "7e0609"),
                                  fillColor: useMonochrome ? monochromeFillColor : .red)
                    }
                    if enabledButtons.contains(.minimize) {
                        buttonFor(action: .minimize, symbol: "minus",
                                  color: useMonochrome ? .secondary : Color(hex: "985712"),
                                  fillColor: useMonochrome ? monochromeFillColor : .yellow)
                    }
                    if enabledButtons.contains(.toggleFullScreen) {
                        buttonFor(action: .toggleFullScreen, symbol: "arrow.up.left.and.arrow.down.right",
                                  color: useMonochrome ? .secondary : Color(hex: "0d650d"),
                                  fillColor: useMonochrome ? monochromeFillColor : .green)
                    }
                    if enabledButtons.contains(.maximize) {
                        buttonFor(action: .maximize, symbol: "arrow.up.to.line",
                                  color: useMonochrome ? .secondary : Color(hex: "0a5a4a"),
                                  fillColor: useMonochrome ? monochromeFillColor : .teal)
                    }
                    if enabledButtons.contains(.openNewWindow) {
                        buttonFor(action: .openNewWindow, symbol: "plus",
                                  color: useMonochrome ? .secondary : Color(hex: "0050A0"),
                                  fillColor: useMonochrome ? monochromeFillColor : .blue)
                    }
                }
                .padding(4)
                .allowsHitTesting(opacity != 0)
                .simultaneousGesture(TapGesture())
                .onHover { isHovering in
                    withAnimation(.snappy(duration: 0.175)) {
                        self.isHovering = isHovering
                    }
                }
            }
        }
        .if(pillStyling && displayMode != .never && enabledButtons.count > 0) { view in
            view.materialPill()
        }
        .opacity(opacity)
    }

    private var opacity: Double {
        switch displayMode {
        case .hiddenUntilHover:
            hoveringOverParentWindow || mockPreviewActive ? 1.0 : 0
        case .dimmedOnPreviewHover:
            (hoveringOverParentWindow && isHovering) || mockPreviewActive ? 1.0 : 0.25
        case .fullOpacityOnPreviewHover:
            hoveringOverParentWindow || mockPreviewActive ? 1 : 0.25
        case .alwaysVisible:
            1
        case .never:
            0
        }
    }

    private func buttonFor(action: WindowAction, symbol: String, color: Color, fillColor: Color) -> some View {
        TrafficLightButton(
            action: action,
            symbol: symbol,
            color: color,
            fillColor: fillColor,
            disableHoverEffect: mockPreviewActive || disableButtonHoverEffects,
            onWindowAction: onWindowAction
        )
    }
}

private struct TrafficLightButton: View {
    let action: WindowAction
    let symbol: String
    let color: Color
    let fillColor: Color
    let disableHoverEffect: Bool
    let onWindowAction: (WindowAction) -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack {
            Image(systemName: "circle.fill")
                .foregroundStyle(.secondary)
            Image(systemName: "\(symbol).circle.fill")
        }
        .foregroundStyle(color, fillColor)
        .font(.headline)
        .overlay {
            if isHovering, !disableHoverEffect {
                Circle()
                    .fill(Color.black.opacity(0.25))
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            if !disableHoverEffect {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovering = hovering
                }
            }
        }
        .onTapGesture {
            onWindowAction(action)
        }
    }
}

extension AppearanceSettingsView {
    private static let trafficLightButtonDescriptions: [(WindowAction, String)] = [
        (.quit, String(localized: "Quit")),
        (.close, String(localized: "Close")),
        (.minimize, String(localized: "Minimize")),
        (.toggleFullScreen, String(localized: "Fullscreen")),
        (.maximize, String(localized: "Maximize")),
        (.openNewWindow, String(localized: "New Window")),
    ]

    struct ContextTrafficLightButtonsSettingsView: View {
        @Binding var visibility: TrafficLightButtonsVisibility
        @Binding var enabledButtons: Set<WindowAction>
        @Binding var useMonochrome: Bool
        var disableButtonHoverEffects: Binding<Bool>?
        var disableDockStyle: Binding<Bool>?

        @State private var isHoveringOverPreview: Bool = false

        var body: some View {
            Picker("Visibility", selection: $visibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { vis in
                    Text(vis.localizedName)
                        .tag(vis)
                }
            }

            if let disableDockStyle, visibility != .never {
                VStack(alignment: .leading) {
                    Toggle(isOn: disableDockStyle) {
                        Text(String(localized: "Disable dock styling on traffic light buttons", comment: "Traffic light buttons setting toggle"))
                    }
                    Text(String(localized: "Removes the pill-shaped background styling from traffic light buttons in dock previews for a cleaner look.", comment: "Traffic light buttons setting description"))
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.leading, 20)
                }
            }

            if visibility != .never {
                Group {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Enabled Buttons", comment: "Traffic light buttons setting section title"))
                        if !enabledButtons.isEmpty {
                            TrafficLightButtons(
                                displayMode: visibility,
                                hoveringOverParentWindow: isHoveringOverPreview,
                                onWindowAction: { _ in },
                                pillStyling: !(disableDockStyle?.wrappedValue ?? false),
                                mockPreviewActive: false,
                                enabledButtons: enabledButtons,
                                useMonochrome: useMonochrome,
                                disableButtonHoverEffects: disableButtonHoverEffects?.wrappedValue ?? false
                            )
                            .onHover { hovering in
                                isHoveringOverPreview = hovering
                            }
                        }
                    }

                    ButtonToggleGrid(
                        enabledButtons: $enabledButtons,
                        visibility: $visibility,
                        showAlertOnEmpty: true
                    )

                    Toggle("Use Monochrome Colors", isOn: $useMonochrome)
                        .padding(.top, 4)

                    if let disableHover = disableButtonHoverEffects {
                        Toggle("Disable Button Hover Effects", isOn: disableHover)
                            .padding(.top, 4)
                    }
                }
            }
        }
    }

    struct EmbeddedButtonsSelector: View {
        @Binding var enabledButtons: Set<WindowAction>

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Enabled Buttons", comment: "Traffic light buttons setting section title"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                ButtonToggleGrid(
                    enabledButtons: $enabledButtons,
                    visibility: .constant(.alwaysVisible),
                    showAlertOnEmpty: false
                )
            }
            .padding(.top, 4)
        }
    }

    struct ButtonToggleGrid: View {
        @Binding var enabledButtons: Set<WindowAction>
        @Binding var visibility: TrafficLightButtonsVisibility
        var showAlertOnEmpty: Bool = true

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ForEach(trafficLightButtonDescriptions.prefix(3), id: \.0) { action, label in
                        buttonToggle(action: action, label: label)
                    }
                }
                HStack(spacing: 12) {
                    ForEach(trafficLightButtonDescriptions.suffix(3), id: \.0) { action, label in
                        buttonToggle(action: action, label: label)
                    }
                }
            }
        }

        private func buttonToggle(action: WindowAction, label: String) -> some View {
            Toggle(isOn: Binding(
                get: { enabledButtons.contains(action) },
                set: { isEnabled in
                    if isEnabled {
                        enabledButtons.insert(action)
                    } else {
                        enabledButtons.remove(action)
                        if showAlertOnEmpty, enabledButtons.isEmpty {
                            MessageUtil.showAlert(
                                title: String(localized: "All buttons removed"),
                                message: String(localized: "Your traffic lights will be set to disabled automatically."),
                                actions: [.ok, .cancel]
                            ) { alertAction in
                                switch alertAction {
                                case .ok:
                                    visibility = .never
                                case .cancel:
                                    break
                                }
                            }
                        }
                    }
                }
            )) {
                Text(label)
            }
            .toggleStyle(CheckboxToggleStyle())
        }
    }
}
