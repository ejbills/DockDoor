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
    var buttonScale: CGFloat = 1.0
    let backgroundAppearance: BackgroundAppearance
    @State private var isHovering = false

    var body: some View {
        Group {
            if displayMode != .never {
                HStack(spacing: 6) {
                    if enabledButtons.contains(.quit) {
                        buttonFor(action: .quit, symbol: "power",
                                  color: Color(red: 0.29, green: 0.01, blue: 0.10),
                                  fillColor: Color(red: 0.88, green: 0.22, blue: 0.42))
                    }
                    if enabledButtons.contains(.close) {
                        buttonFor(action: .close, symbol: "xmark",
                                  color: Color(red: 0.49, green: 0.02, blue: 0.04),
                                  fillColor: Color(red: 1.00, green: 0.30, blue: 0.28))
                    }
                    if enabledButtons.contains(.minimize) {
                        buttonFor(action: .minimize, symbol: "minus",
                                  color: Color(red: 0.60, green: 0.34, blue: 0.07),
                                  fillColor: Color(red: 1.00, green: 0.80, blue: 0.20))
                    }
                    if enabledButtons.contains(.toggleFullScreen) {
                        buttonFor(action: .toggleFullScreen, symbol: "arrow.up.left.and.arrow.down.right",
                                  color: Color(red: 0.05, green: 0.40, blue: 0.05),
                                  fillColor: Color(red: 0.26, green: 0.84, blue: 0.36))
                    }
                    if enabledButtons.contains(.maximize) {
                        buttonFor(action: .maximize, symbol: "arrow.up.to.line",
                                  color: Color(red: 0.07, green: 0.22, blue: 0.32),
                                  fillColor: Color(red: 0.25, green: 0.52, blue: 0.72))
                    }
                    if enabledButtons.contains(.bringToCurrentSpace) {
                        buttonFor(action: .bringToCurrentSpace, symbol: "arrow.right",
                                  color: Color(red: 0.02, green: 0.24, blue: 0.32),
                                  fillColor: Color(red: 0.08, green: 0.62, blue: 0.86))
                    }
                    if enabledButtons.contains(.openNewWindow) {
                        buttonFor(action: .openNewWindow, symbol: "plus",
                                  color: Color(red: 0.04, green: 0.16, blue: 0.40),
                                  fillColor: Color(red: 0.42, green: 0.60, blue: 0.98))
                    }
                }
                .padding(4)
                .opacity(opacity)
                .if(pillStyling && opacity > 0 && enabledButtons.count > 0) { view in
                    view.materialPill(backgroundAppearance: backgroundAppearance)
                }
                .allowsHitTesting(opacity != 0)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture())
                .onHover { isHovering in
                    withAnimation(.snappy(duration: 0.175)) {
                        self.isHovering = isHovering
                    }
                }
            }
        }
    }

    private var opacity: Double {
        switch displayMode {
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
        let monochromeFillColor = colorScheme == .dark ? Color.gray.opacity(0.85) : Color.white
        return ZStack {
            TrafficLightOrb(base: useMonochrome ? monochromeFillColor : fillColor, diameter: Self.glyphFontSize * 1.0385)
            Image(systemName: "\(symbol).circle.fill")
                .font(.system(size: Self.glyphFontSize, weight: .bold))
                .foregroundStyle(useMonochrome ? AnyShapeStyle(.secondary) : AnyShapeStyle(color), .clear)
        }
        .scaleEffect(buttonScale)
        .frame(width: 17 * buttonScale, height: 17 * buttonScale)
        .contentShape(Rectangle())
        .onTapGesture {
            onWindowAction(action)
        }
    }

    private static let glyphFontSize: CGFloat = 13
}

struct TrafficLightOrb: View {
    let base: Color
    let diameter: CGFloat

    private static let bodyShading = 0.16

    private static let rimStops: [Gradient.Stop] = [
        .init(color: .white.opacity(0.72), location: 0.00),
        .init(color: .white.opacity(0.66), location: 0.03),
        .init(color: .white.opacity(0.48), location: 0.07),
        .init(color: .white.opacity(0.28), location: 0.15),
        .init(color: .white.opacity(0.15), location: 0.25),
        .init(color: .white.opacity(0.04), location: 0.37),
        .init(color: .white.opacity(0.00), location: 0.50),
        .init(color: .white.opacity(0.03), location: 0.63),
        .init(color: .white.opacity(0.12), location: 0.75),
        .init(color: .white.opacity(0.23), location: 0.85),
        .init(color: .white.opacity(0.40), location: 0.93),
        .init(color: .white.opacity(0.55), location: 0.97),
        .init(color: .white.opacity(0.60), location: 1.00),
    ]

    private static let specularRim = LinearGradient(stops: rimStops, startPoint: .top, endPoint: .bottom)

    var body: some View {
        Circle()
            .fill(bodyGradient)
            .overlay {
                Circle()
                    .strokeBorder(Self.specularRim, lineWidth: max(0.5, diameter / 14))
            }
            .frame(width: diameter, height: diameter)
    }

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [base.shaded(by: -Self.bodyShading), base.shaded(by: Self.bodyShading)],
            startPoint: UnitPoint(x: 0.5, y: 0.25),
            endPoint: UnitPoint(x: 0.5, y: 0.75)
        )
    }
}

extension AppearanceSettingsView {
    struct TrafficLightButtonsSettingsView: View {
        @Default(.enabledTrafficLightButtons) private var enabledButtons
        @Default(.useMonochromeTrafficLights) private var useMonochrome
        @Default(.trafficLightButtonsVisibility) private var trafficLightButtonsVisibility
        @Default(.trafficLightButtonScale) private var buttonScale

        private let buttonDescriptions: [(WindowAction, String)] = [
            (.quit, String(localized: "Quit")),
            (.close, String(localized: "Close")),
            (.minimize, String(localized: "Minimize")),
            (.toggleFullScreen, String(localized: "Fullscreen")),
            (.maximize, String(localized: "Maximize")),
            (.bringToCurrentSpace, String(localized: "Bring to Current Space")),
            (.openNewWindow, String(localized: "New Window")),
        ]

        private var buttonRows: [[(WindowAction, String)]] {
            stride(from: 0, to: buttonDescriptions.count, by: 3).map { start in
                Array(buttonDescriptions[start ..< min(start + 3, buttonDescriptions.count)])
            }
        }

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
                                mockPreviewActive: false,
                                enabledButtons: enabledButtons,
                                useMonochrome: useMonochrome,
                                buttonScale: buttonScale,
                                backgroundAppearance: .resolve()
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(buttonRows.indices, id: \.self) { rowIndex in
                                HStack(spacing: 12) {
                                    ForEach(buttonRows[rowIndex], id: \.0) { action, label in
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
                                            Text(label)
                                        }
                                        .toggleStyle(CheckboxToggleStyle())
                                    }
                                }
                            }
                        }
                    }

                    Toggle("Use Monochrome Colors", isOn: $useMonochrome)
                        .padding(.top, 4)

                    sliderSetting(
                        title: "Button Scale",
                        value: $buttonScale,
                        range: 0.75 ... 2.0,
                        step: 0.05,
                        unit: "×",
                        formatter: NumberFormatter.twoDecimalFormatter
                    )
                }
            }
        }
    }
}
