import Defaults
import SwiftUI

struct AdvancedAppearanceSection: View {
    @Default(.selectionOpacity) var selectionOpacity
    @Default(.hoverHighlightColor) var hoverHighlightColor
    @Default(.dockPreviewBackgroundOpacity) var dockPreviewBackgroundOpacity

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup(header: "Window Background") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("All window previews show a gray background. When hovered, the background changes to the accent color or custom color below.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        ColorPicker("Custom Hover Highlight Color", selection: Binding(
                            get: { hoverHighlightColor ?? Color(nsColor: .controlAccentColor) },
                            set: { hoverHighlightColor = $0 }
                        ))
                        Button(action: {
                            Defaults.reset(.hoverHighlightColor)
                        }) {
                            Text("Reset")
                        }
                        .buttonStyle(AccentButtonStyle(small: true))
                    }

                    sliderSetting(
                        title: "Background Opacity",
                        value: $selectionOpacity,
                        range: 0 ... 1,
                        step: 0.05,
                        unit: "",
                        formatter: NumberFormatter.percentFormatter
                    )
                }
            }

            SettingsGroup(header: "Dock Preview Transparency") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Control the transparency of the dock preview background. Lower values make the preview more transparent, which can help prevent it from blocking window content.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    sliderSetting(
                        title: "Background Opacity",
                        value: $dockPreviewBackgroundOpacity,
                        range: 0 ... 1.0,
                        step: 0.05,
                        unit: "",
                        formatter: NumberFormatter.percentFormatter
                    )
                }
            }

            SettingsGroup(header: "Color Customization") {
                GradientColorPaletteSettingsView()
            }
        }
        .padding(.top, 10)
    }
}
