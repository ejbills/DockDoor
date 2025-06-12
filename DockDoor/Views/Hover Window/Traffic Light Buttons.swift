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
    @State private var isHovering = false
    @Default(.enabledTrafficLightButtons) private var enabledButtons
    @Default(.useMonochromeTrafficLights) private var useMonochrome

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
                    if enabledButtons.contains(.openNewWindow) {
                        buttonFor(action: .openNewWindow, symbol: "plus",
                                  color: useMonochrome ? .secondary : Color(hex: "0050A0"),
                                  fillColor: useMonochrome ? monochromeFillColor : .blue)
                    }
                }
                .padding(4)
                .opacity(opacity)
                .allowsHitTesting(opacity != 0)
                .simultaneousGesture(TapGesture())
                .onHover { isHovering in
                    withAnimation(.snappy(duration: 0.175)) {
                        self.isHovering = isHovering
                    }
                }
            }
        }
        .if(pillStyling && opacity > 0 && displayMode != .never && enabledButtons.count > 0) { view in
            view.materialPill()
        }
    }

    private var opacity: Double {
        switch displayMode {
        case .dimmedOnPreviewHover:
            (hoveringOverParentWindow && isHovering) || mockPreviewActive ? 1.0 : 0.25
        case .fullOpacityOnPreviewHover:
            hoveringOverParentWindow || mockPreviewActive ? 1 : 0
        case .alwaysVisible:
            1
        case .never:
            0
        }
    }

    private func buttonFor(action: WindowAction, symbol: String, color: Color, fillColor: Color) -> some View {
        ZStack {
            Image(systemName: "circle.fill")
                .foregroundStyle(.secondary)
            Image(systemName: "\(symbol).circle.fill")
        }
        .foregroundStyle(color, fillColor)
        .font(.headline)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 10, perform: {}, onPressingChanged: { pressing in
            if pressing {
                onWindowAction(action)
            }
        })
    }
}

extension AppearanceSettingsView {
    struct TrafficLightButtonsSettingsView: View {
        @Default(.enabledTrafficLightButtons) private var enabledButtons
        @Default(.useMonochromeTrafficLights) private var useMonochrome
        @Default(.trafficLightButtonsVisibility) private var trafficLightButtonsVisibility

        private let buttonDescriptions: [(WindowAction, String)] = [
            (.quit, String(localized: "Quit")),
            (.close, String(localized: "Close")),
            (.minimize, String(localized: "Minimize")),
            (.toggleFullScreen, String(localized: "Fullscreen")),
            (.openNewWindow, String(localized: "New Window")),
        ]

        var body: some View {
            Picker("Traffic Light Buttons Visibility", selection: $trafficLightButtonsVisibility) {
                ForEach(TrafficLightButtonsVisibility.allCases, id: \.self) { visibility in
                    Text(visibility.localizedName)
                        .tag(visibility)
                }
            }

            if trafficLightButtonsVisibility != .never {
                Group {
                    Text("Enabled Buttons")
                    VStack(alignment: .leading) {
                        if !enabledButtons.isEmpty {
                            TrafficLightButtons(
                                displayMode: trafficLightButtonsVisibility == .never ? .dimmedOnPreviewHover : trafficLightButtonsVisibility,
                                hoveringOverParentWindow: true,
                                onWindowAction: { _ in },
                                pillStyling: true,
                                mockPreviewActive: false
                            )
                        }

                        HStack(spacing: 12) {
                            ForEach(buttonDescriptions, id: \.0) { action, label in
                                Toggle(isOn: Binding(
                                    get: { enabledButtons.contains(action) },
                                    set: { isEnabled in
                                        if isEnabled {
                                            enabledButtons.insert(action)
                                        } else {
                                            enabledButtons.remove(action)

                                            if enabledButtons.isEmpty {
                                                MessageUtil.showAlert(
                                                    title: String(localized: "All buttons removed"),
                                                    message: String(localized: "Your traffic lights will be set to disabled automatically."),
                                                    actions: [.ok, .cancel]
                                                ) { action in
                                                    switch action {
                                                    case .ok:
                                                        trafficLightButtonsVisibility = .never
                                                    case .cancel:
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                    }
                                )) {
                                    HStack {
                                        Text(label)
                                    }
                                }
                                .toggleStyle(CheckboxToggleStyle())
                            }
                        }
                    }

                    Toggle("Use Monochrome Colors", isOn: $useMonochrome)
                        .padding(.top, 4)
                }
            }
        }
    }
}
