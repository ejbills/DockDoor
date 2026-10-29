import Defaults
import SwiftUI

struct AdvancedAppearanceSection: View {
    @Default(.selectionOpacity) var selectionOpacity
    @Default(.hoverHighlightColor) var hoverHighlightColor
    @Default(.dockPreviewBackgroundOpacity) var dockPreviewBackgroundOpacity
    @Default(.useOpaquePreviewBackground) var useOpaquePreviewBackground
    @Default(.customBackgroundColor) var customBackgroundColor

    var body: some View {
        SettingsSection("Window Background") {
            LabeledContent("Custom Hover Highlight Color") {
                HStack(spacing: 8) {
                    ColorPicker("Custom Hover Highlight Color", selection: Binding(
                        get: { hoverHighlightColor ?? Color(nsColor: .controlAccentColor) },
                        set: { hoverHighlightColor = $0 }
                    ))
                    .labelsHidden()
                    SettingsResetButton(isModified: hoverHighlightColor != nil) {
                        Defaults.reset(.hoverHighlightColor)
                    }
                }
            }
            .settingsSearchTarget("appearance.hoverHighlightColor")
            .settingsAnnotation("All window previews show a gray background. When hovered, the background changes to the accent color or custom color below.")

            SettingsSliderRow(
                title: "Background Opacity",
                value: $selectionOpacity,
                range: 0 ... 1,
                step: 0.05
            )
            .settingsSearchTarget("appearance.selectionOpacity")
        }

        SettingsSection("Dock Preview Transparency") {
            Picker("Background", selection: backgroundChoice) {
                ForEach(PreviewBackgroundChoice.allCases) { choice in
                    Text(choice.localizedName).tag(choice)
                }
            }
            .settingsSearchTarget("appearance.opaqueBackground")
            .settingsAnnotation("Blurred lets the desktop show through; solid and custom colors are easier to read over busy windows.")

            switch backgroundChoice.wrappedValue {
            case .blurred:
                SettingsSliderRow(
                    title: "Background Opacity",
                    value: $dockPreviewBackgroundOpacity,
                    range: 0 ... 1.0,
                    step: 0.05
                )
                .settingsSearchTarget("appearance.dockPreviewOpacity")
                .settingsAnnotation("Control the transparency of the dock preview background. Lower values make the preview more transparent, which can help prevent it from blocking window content.")
            case .solid:
                EmptyView()
            case .custom:
                ColorPicker("Custom Background Color", selection: Binding(
                    get: { customBackgroundColor ?? Color(nsColor: .windowBackgroundColor) },
                    set: { customBackgroundColor = $0 }
                ))
                .settingsSearchTarget("appearance.customBackgroundColor")
            }
        }

        SettingsSection("Color Customization") {
            GradientColorPaletteSettingsView()
        }
    }

    /// A custom color wins over opaque; neither means blurred.
    private var backgroundChoice: Binding<PreviewBackgroundChoice> {
        Binding {
            if customBackgroundColor != nil {
                return .custom
            }
            return useOpaquePreviewBackground ? .solid : .blurred
        } set: { choice in
            switch choice {
            case .blurred:
                customBackgroundColor = nil
                useOpaquePreviewBackground = false
            case .solid:
                customBackgroundColor = nil
                useOpaquePreviewBackground = true
            case .custom:
                if customBackgroundColor == nil {
                    customBackgroundColor = Color(nsColor: .windowBackgroundColor)
                }
            }
        }
    }
}

private enum PreviewBackgroundChoice: CaseIterable, Identifiable {
    case blurred
    case solid
    case custom

    var id: Self {
        self
    }

    var localizedName: String {
        switch self {
        case .blurred: String(localized: "Blurred", comment: "Dock preview background option")
        case .solid: String(localized: "Solid", comment: "Dock preview background option")
        case .custom: String(localized: "Custom color", comment: "Dock preview background option")
        }
    }
}
