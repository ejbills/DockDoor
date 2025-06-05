import Cocoa
import Combine
import Defaults
import SwiftUI

struct GradientColorPaletteSettingsView: View {
    @Default(.gradientColorPalette) var storedSettings
    @State private var editingColor: String?
    @State private var editingIndex: Int?
    @State private var tempColor: Color = .black
    @State private var colorUpdatePublisher = PassthroughSubject<Color, Never>()
    @State private var cancellables = Set<AnyCancellable>()

    let maxColors = 8

    var body: some View {
        HStack(alignment: .top) {
            Text("Highlight Gradient Colors")
                .layoutPriority(1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(storedSettings.colors.indices, id: \.self) { index in
                        colorShape(for: storedSettings.colors[index], index: index)
                    }
                }

                Text("Right click a color to remove it.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()

            if editingIndex != nil, editingColor != nil {
                ColorPicker("Edit Color", selection: $tempColor)
                    .labelsHidden()
                    .onChange(of: tempColor) { newValue in
                        colorUpdatePublisher.send(newValue)
                    }
            }
            Button(action: addRandomColor) {
                Image(systemName: "plus")
                    .frame(width: 30, height: 30)
            }
        }

        sliderSetting(title: "Animation speed",
                      value: $storedSettings.speed,
                      range: 0.1 ... 1.0,
                      step: 0.05,
                      unit: "seconds",
                      formatter: NumberFormatter.twoDecimalFormatter)

        sliderSetting(title: "Blur amount",
                      value: $storedSettings.blur,
                      range: 0 ... 1.0,
                      step: 0.05,
                      unit: "amount",
                      formatter: NumberFormatter.twoDecimalFormatter)
            .onAppear {
                setupColorDebounce()
            }
    }

    private func colorShape(for hexColor: String, index: Int) -> some View {
        Circle()
            .fill(Color(hex: hexColor))
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(editingIndex == index ? Color.white : Color.clear, lineWidth: 2)
            )
            .onTapGesture {
                withAnimation(.snappy(duration: 0.125)) {
                    if editingColor == hexColor, editingIndex == index { // no change, remove selection
                        editingColor = nil
                        editingIndex = nil
                    } else {
                        editingColor = hexColor
                        editingIndex = index
                        tempColor = Color(hex: hexColor)
                    }
                }
            }
            .contextMenu {
                Button("Remove") {
                    removeColor(at: index)
                }
            }
    }

    private func addRandomColor() {
        let newColor = Color(
            red: .random(in: 0 ... 1),
            green: .random(in: 0 ... 1),
            blue: .random(in: 0 ... 1)
        )
        if let hex = newColor.toHex() {
            guard storedSettings.colors.count < maxColors else {
                showMaximumColorsAlert()
                return
            }
            storedSettings.colors.append(hex)
        }
    }

    private func removeColor(at index: Int) {
        guard storedSettings.colors.count > 1 else {
            showMinimumColorsAlert()
            return
        }
        storedSettings.colors.remove(at: index)

        if editingIndex == index {
            editingColor = nil
            editingIndex = nil
        }
    }

    private func showMinimumColorsAlert() {
        MessageUtil.showAlert(
            title: String(localized: "Cannot Remove Color"),
            message: String(localized: "Minimum number of colors reached."),
            actions: [.ok, .cancel]
        ) { action in
            switch action {
            case .ok:
                print("User acknowledged the minimum colors alert")
            case .cancel:
                print("User cancelled the minimum colors alert")
            }
        }
    }

    private func showMaximumColorsAlert() {
        MessageUtil.showAlert(
            title: String(localized: "Cannot Add Color"),
            message: String(localized: "Maximum number of colors (\(maxColors)) reached."),
            actions: [.ok, .cancel]
        ) { action in
            switch action {
            case .ok:
                print("User acknowledged the maximum colors alert")
            case .cancel:
                print("User cancelled the maximum colors alert")
            }
        }
    }

    private func setupColorDebounce() {
        colorUpdatePublisher
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { newColor in
                guard let editingIndex else { return }
                if let newHex = newColor.toHex() {
                    editingColor = newHex
                    storedSettings.colors[editingIndex] = newHex
                }
            }
            .store(in: &cancellables)
    }
}
