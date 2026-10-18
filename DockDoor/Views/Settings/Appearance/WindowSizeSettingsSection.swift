import Defaults
import SwiftUI

struct WindowSizeSettingsSection: View {
    var body: some View {
        SettingsSection("Window preview size") {
            WindowSizeSliderView()

            Text("Choose how large window previews appear when hovering over dock icons. All window images are automatically scaled to fit within this size while maintaining their original proportions.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct WindowSizeSliderView: View {
    @Default(.previewWidth) var previewWidth
    @Default(.previewHeight) var previewHeight
    @Default(.lockAspectRatio) var lockAspectRatio
    @Default(.allowDynamicImageSizing) var allowDynamicImageSizing

    private let aspectRatio: CGFloat = 16.0 / 10.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $lockAspectRatio) {
                Text("Lock aspect ratio (16:10)")
            }
            .settingsSearchTarget("appearance.lockAspect")
            .onChange(of: lockAspectRatio) { newValue in
                if newValue {
                    previewHeight = previewWidth / aspectRatio
                }
                updateWindowSize()
            }

            Toggle(isOn: $allowDynamicImageSizing) {
                Text("Dynamic image sizing")
            }
            .settingsSearchTarget("appearance.dynamicSizing")
            Text("Scale previews to match actual window proportions instead of using fixed dimensions.")
                .font(.caption)
                .foregroundColor(.secondary)

            SettingsSliderRow(
                title: "Preview Width",
                value: $previewWidth,
                range: 100.0 ... 600.0,
                unit: " px",
                step: 10.0,
                decimals: 0
            )
            .settingsSearchTarget("appearance.previewWidth")
            .onChange(of: previewWidth) { _ in
                if lockAspectRatio {
                    previewHeight = previewWidth / aspectRatio
                }
                updateWindowSize()
            }

            SettingsSliderRow(
                title: "Preview Height",
                value: $previewHeight,
                range: 60.0 ... 400.0,
                unit: " px",
                step: 10.0,
                decimals: 0
            )
            .settingsSearchTarget("appearance.previewHeight")
            .disabled(lockAspectRatio)
            .onChange(of: previewHeight) { _ in
                if lockAspectRatio {
                    previewWidth = previewHeight * aspectRatio
                }
                updateWindowSize()
            }

            Text("Current aspect ratio: \(formatAspectRatio(previewWidth / previewHeight))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func updateWindowSize() {
        SharedPreviewWindowCoordinator.activeInstance?.windowSize = getWindowSize()
    }

    private func formatAspectRatio(_ ratio: CGFloat) -> String {
        let commonRatios: [(ratio: CGFloat, display: String)] = [
            (16.0 / 9.0, "16:9"),
            (16.0 / 10.0, "16:10"),
            (4.0 / 3.0, "4:3"),
            (3.0 / 2.0, "3:2"),
            (21.0 / 9.0, "21:9"),
            (1.0, "1:1"),
        ]

        for commonRatio in commonRatios {
            if abs(ratio - commonRatio.ratio) < 0.01 {
                return commonRatio.display
            }
        }

        return String(format: "%.2f:1", ratio)
    }
}
