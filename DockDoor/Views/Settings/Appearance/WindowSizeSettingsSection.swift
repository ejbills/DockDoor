import Defaults
import SwiftUI

struct WindowSizeSettingsSection: View {
    var body: some View {
        SettingsGroup(header: "Window Preview Size") {
            VStack(alignment: .leading, spacing: 10) {
                WindowSizeSliderView()

                Text("Choose how large window previews appear when hovering over dock icons. All window images are automatically scaled to fit within this size while maintaining their original proportions.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct WindowSizeSliderView: View {
    @Default(.previewWidth) var previewWidth
    @Default(.previewHeight) var previewHeight
    @Default(.lockAspectRatio) var lockAspectRatio

    private let aspectRatio: CGFloat = 16.0 / 10.0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $lockAspectRatio) {
                Text("Lock aspect ratio (16:10)")
            }
            .onChange(of: lockAspectRatio) { newValue in
                if newValue {
                    previewHeight = previewWidth / aspectRatio
                }
                updateWindowSize()
            }

            sliderSetting(
                title: "Preview Width",
                value: $previewWidth,
                range: 100.0 ... 600.0,
                step: 10.0,
                unit: "px",
                formatter: {
                    let f = NumberFormatter()
                    f.minimumFractionDigits = 0
                    f.maximumFractionDigits = 0
                    return f
                }()
            )
            .onChange(of: previewWidth) { _ in
                if lockAspectRatio {
                    previewHeight = previewWidth / aspectRatio
                }
                updateWindowSize()
            }

            sliderSetting(
                title: "Preview Height",
                value: $previewHeight,
                range: 60.0 ... 400.0,
                step: 10.0,
                unit: "px",
                formatter: {
                    let f = NumberFormatter()
                    f.minimumFractionDigits = 0
                    f.maximumFractionDigits = 0
                    return f
                }()
            )
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
