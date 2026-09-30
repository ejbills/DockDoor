import Defaults
import SwiftUI

struct BackgroundAppearanceSection: View {
    @Default(.dockBackgroundStyle) var backgroundStyle
    @Default(.dockLiquidGlassFlavor) var glassFlavor
    @Default(.dockGlassRefraction) var glassRefraction
    @Default(.dockGlassOpacity) var glassOpacity
    @Default(.dockGlassBlurRadius) var blurRadius
    @Default(.dockGlassSaturation) var saturation
    @Default(.dockGlassVariant) var glassVariant
    @Default(.dockBackgroundTintOpacity) var tintOpacity
    @Default(.dockBackgroundBorderOpacity) var borderOpacity
    @Default(.dockBackgroundBorderWidth) var borderWidth
    @Default(.dockBackgroundMaterial) var material

    private var isGlass: Bool { backgroundStyle == .liquidGlass }
    private var isFrosted: Bool { backgroundStyle == .frostedMaterial }

    var body: some View {
        SettingsGroup(header: "Background") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Style")
                        .font(.body)
                    Spacer()
                    Picker("", selection: $backgroundStyle) {
                        if #available(macOS 26.0, *) {
                            ForEach(DockBackgroundStyle.allAvailable, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        } else {
                            ForEach(DockBackgroundStyle.preTahoe, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 250)
                    .settingsSearchTarget("appearance.backgroundStyle")
                }

                if isFrosted {
                    HStack {
                        Text("Material")
                            .font(.body)
                        Spacer()
                        Picker("", selection: $material) {
                            ForEach(DockBackgroundMaterial.allCases, id: \.self) { mat in
                                Text(mat.displayName).tag(mat)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 150)
                    }
                    .settingsSearchTarget("appearance.material")
                }

                if isGlass {
                    if #available(macOS 26.0, *), LiquidGlass.usesModernPipeline {
                        glassSettings
                    } else {
                        DisclosureGroup("Glass Tuning") {
                            VStack(alignment: .leading, spacing: 8) {
                                if #available(macOS 26.0, *) {
                                    HStack {
                                        Text("Variant")
                                            .font(.body)
                                        Spacer()
                                        Slider(
                                            value: Binding(
                                                get: { Double(glassVariant) },
                                                set: { glassVariant = Int($0.rounded()) }
                                            ),
                                            in: 0 ... 20,
                                            step: 1
                                        )
                                        .frame(maxWidth: 160)
                                        Stepper(value: $glassVariant, in: 0 ... 20) {
                                            Text("\(glassVariant)")
                                                .font(.body.monospacedDigit())
                                                .frame(minWidth: 20, alignment: .trailing)
                                        }
                                        .fixedSize()
                                    }
                                    .settingsSearchTarget("appearance.glassVariant")
                                }

                                sliderSetting(
                                    title: "Opacity",
                                    value: $glassOpacity,
                                    range: 0 ... 1.0,
                                    step: 0.05,
                                    unit: "",
                                    formatter: NumberFormatter.percentFormatter
                                )

                                sliderSetting(
                                    title: "Blur Radius",
                                    value: $blurRadius,
                                    range: 0 ... 80,
                                    step: 1,
                                    unit: "pt"
                                )

                                sliderSetting(
                                    title: "Saturation",
                                    value: $saturation,
                                    range: 0 ... 2.0,
                                    step: 0.05,
                                    unit: "",
                                    formatter: NumberFormatter.percentFormatter
                                )

                                sliderSetting(
                                    title: "Tint Intensity",
                                    value: $tintOpacity,
                                    range: 0 ... 1.0,
                                    step: 0.05,
                                    unit: "",
                                    formatter: NumberFormatter.percentFormatter
                                )

                                sliderSetting(
                                    title: "Border Opacity",
                                    value: $borderOpacity,
                                    range: 0 ... 1.0,
                                    step: 0.05,
                                    unit: "",
                                    formatter: NumberFormatter.percentFormatter
                                )

                                sliderSetting(
                                    title: "Border Width",
                                    value: $borderWidth,
                                    range: 0 ... 4.0,
                                    step: 0.5,
                                    unit: "pt"
                                )

                                Button("Reset to Defaults") {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        Defaults.reset(
                                            .dockGlassOpacity,
                                            .dockGlassBlurRadius,
                                            .dockGlassSaturation,
                                            .dockGlassVariant,
                                            .dockBackgroundTintOpacity,
                                            .dockBackgroundBorderOpacity,
                                            .dockBackgroundBorderWidth
                                        )
                                    }
                                }
                                .buttonStyle(AccentButtonStyle(small: true))
                                .padding(.top, 4)
                            }
                            .padding(.top, 6)
                        }
                        .font(.body)
                        .settingsSearchTarget("appearance.glassTuning")
                    }
                }
            }
        }
    }

    @available(macOS 26.0, *)
    @ViewBuilder
    private var glassSettings: some View {
        let flavors = LiquidGlass.availableFlavors
        if flavors.count > 1 {
            HStack {
                Text("Opacity")
                    .font(.body)
                Spacer()
                HStack(spacing: 8) {
                    Text("Clearer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Slider(value: glassFlavorIndex(in: flavors), in: 0 ... Double(flavors.count - 1), step: 1)
                    Text("More Opaque")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 250)
            }
            .settingsSearchTarget("appearance.glassOpacity")
        }

        VStack(alignment: .leading) {
            Toggle(isOn: $glassRefraction) {
                Text("Refraction")
            }
            Text("Bends the background at the edges and adds a bright rim. Turn off for softer frosted glass that is easier to read over busy backgrounds.")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.leading, 20)
        }
        .settingsSearchTarget("appearance.glassRefraction")
    }

    @available(macOS 26.0, *)
    private func glassFlavorIndex(in flavors: [DockLiquidGlassFlavor]) -> Binding<Double> {
        Binding(
            get: { Double(LiquidGlass.sliderIndex(for: glassFlavor)) },
            set: { newValue in
                let index = Int(newValue.rounded())
                guard flavors.indices.contains(index), flavors[index] != glassFlavor else { return }
                glassFlavor = flavors[index]
            }
        )
    }
}
