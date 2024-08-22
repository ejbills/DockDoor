import Defaults
import SwiftUI

import Defaults
import SwiftUI

struct GradientColorPaletteSettingsView: View {
    @Default(.gradientColorPalette) var storedSettings
    @State private var localSettings: GradientColorPaletteSettings

    init() {
        _localSettings = State(initialValue: Defaults[.gradientColorPalette])
    }

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Blob Colors")) {
                    HStack {
                        ForEach(0 ..< localSettings.blobs.count, id: \.self) { index in
                            ColorPicker("Blob \(index + 1)", selection: $localSettings.blobs[index])
                        }
                    }
                    HStack {
                        Button("Add Blob Color") {
                            localSettings.blobs.append(.white)
                        }
                        .disabled(localSettings.blobs.count >= 10)
                        Button("Remove Last Blob Color") {
                            _ = localSettings.blobs.popLast()
                        }
                        .disabled(localSettings.blobs.count <= 2)
                    }
                }
                Section(header: Text("Highlight Colors")) {
                    HStack {
                        ForEach(0 ..< localSettings.highlights.count, id: \.self) { index in
                            ColorPicker("Highlight \(index + 1)", selection: $localSettings.highlights[index])
                        }
                    }
                    HStack {
                        Button("Add Highlight Color") {
                            localSettings.highlights.append(.white)
                        }
                        .disabled(localSettings.highlights.count >= 10)
                        Button("Remove Last Highlight Color") {
                            _ = localSettings.highlights.popLast()
                        }
                        .disabled(localSettings.highlights.count <= 2)
                    }
                }
                Section(header: Text("Animation Settings")) {
                    Slider(value: $localSettings.speed, in: 0.1 ... 1.0, step: 0.05) {
                        Text("Animation Speed: \(localSettings.speed, specifier: "%.2f")")
                    }

                    Slider(value: $localSettings.blur, in: 0.0 ... 1.0, step: 0.05) {
                        Text("Blur Amount: \(localSettings.blur, specifier: "%.2f")")
                    }
                }
            }
        }
        .onChange(of: localSettings) { _, _ in saveChanges() }
    }

    private func saveChanges() {
        Defaults[.gradientColorPalette] = localSettings
        storedSettings = localSettings
        print("Saved settings - Blobs: \(storedSettings.blobs)")
        print("Local settings - Blobs: \(localSettings.blobs)")
    }
}
