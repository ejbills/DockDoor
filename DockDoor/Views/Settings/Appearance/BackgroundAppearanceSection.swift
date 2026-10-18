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
    @Default(.showPreviewShadow) var showPreviewShadow
    @Default(.previewShadowRadius) var previewShadowRadius
    @Default(.previewShadowOpacity) var previewShadowOpacity

    private var isGlass: Bool {
        backgroundStyle == .liquidGlass
    }

    private var isFrosted: Bool {
        backgroundStyle == .frostedMaterial
    }

    var body: some View {
        SettingsSection("Background") {
            Picker("Style", selection: $backgroundStyle) {
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
            .settingsSearchTarget("appearance.backgroundStyle")

            if isFrosted {
                Picker("Material", selection: $material) {
                    ForEach(DockBackgroundMaterial.allCases, id: \.self) { mat in
                        Text(mat.displayName).tag(mat)
                    }
                }
                .settingsSearchTarget("appearance.material")
            }

            if isGlass {
                if #available(macOS 26.0, *), LiquidGlass.usesModernPipeline {
                    glassSettings
                } else {
                    DisclosureGroup("Glass Tuning") {
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

                        SettingsSliderRow(
                            title: "Opacity",
                            value: $glassOpacity,
                            range: 0 ... 1.0,
                            step: 0.05
                        )

                        SettingsSliderRow(
                            title: "Blur Radius",
                            value: $blurRadius,
                            range: 0 ... 80,
                            unit: " pt",
                            step: 1
                        )

                        SettingsSliderRow(
                            title: "Saturation",
                            value: $saturation,
                            range: 0 ... 2.0,
                            step: 0.05
                        )

                        SettingsSliderRow(
                            title: "Tint Intensity",
                            value: $tintOpacity,
                            range: 0 ... 1.0,
                            step: 0.05
                        )

                        SettingsSliderRow(
                            title: "Border Opacity",
                            value: $borderOpacity,
                            range: 0 ... 1.0,
                            step: 0.05
                        )

                        SettingsSliderRow(
                            title: "Border Width",
                            value: $borderWidth,
                            range: 0 ... 4.0,
                            unit: " pt",
                            step: 0.5
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
                        .buttonStyle(.settings)
                        .padding(.top, 4)
                    }
                    .font(.body)
                    .settingsSearchTarget("appearance.glassTuning")
                }
            }

            Toggle(isOn: $showPreviewShadow) {
                Text("Show shadow beneath previews")
            }
            .settingsAnnotation("Casts a soft shadow around preview panels so their edges stay visible over light backgrounds.")
            .settingsSearchTarget("appearance.previewShadow")

            if showPreviewShadow {
                SettingsSliderRow(
                    title: "Shadow Size",
                    value: $previewShadowRadius,
                    range: 2 ... 10,
                    unit: " pt",
                    step: 1
                )

                SettingsSliderRow(
                    title: "Shadow Opacity",
                    value: $previewShadowOpacity,
                    range: 0.05 ... 1.0,
                    step: 0.05
                )
            }
        }
    }

    @available(macOS 26.0, *)
    @ViewBuilder
    private var glassSettings: some View {
        let flavors = LiquidGlass.availableFlavors
        if flavors.count > 1 {
            LabeledContent("Opacity") {
                HStack(spacing: 8) {
                    Text("Clearer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Slider(value: glassFlavorIndex(in: flavors), in: 0 ... Double(flavors.count - 1), step: 1)
                        .labelsHidden()
                        .frame(width: 180)
                    Text("More Opaque")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .settingsSearchTarget("appearance.glassOpacity")
        }

        Toggle(isOn: $glassRefraction) {
            Text("Refraction")
        }
        .settingsAnnotation("Bends the background at the edges and adds a bright rim. Turn off for softer frosted glass that is easier to read over busy backgrounds.")
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
