import Defaults
import SwiftUI

struct BackgroundAppearanceSection: View {
    @Default(.dockBackgroundStyle) var backgroundStyle
    @Default(.dockGlassOpacity) var glassOpacity
    @Default(.dockGlassBlurRadius) var blurRadius
    @Default(.dockGlassSaturation) var saturation
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
                    DisclosureGroup("Glass Tuning") {
                        VStack(alignment: .leading, spacing: 8) {
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
