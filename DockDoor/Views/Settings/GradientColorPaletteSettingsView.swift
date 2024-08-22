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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                ForEach(storedSettings.colors.indices, id: \.self) { index in
                    colorShape(for: storedSettings.colors[index], index: index)
                }

                Button(action: addRandomColor) {
                    Image(systemName: "plus")
                        .frame(width: 30, height: 30)
                }
            }

            if let editingIndex {
                ColorPicker("Edit Color", selection: $tempColor)
                    .labelsHidden()
                    .onChange(of: tempColor) { _, newValue in
                        colorUpdatePublisher.send(newValue)
                    }
            }

            Text("Right click colors to remove it.")
                .font(.caption)
                .foregroundColor(.gray)

            HStack {
                Text("Animation speed")
                    .layoutPriority(1)
                Spacer()
                Slider(value: $storedSettings.speed, in: 0.1 ... 1.0, step: 0.05)
                TextField("", value: $storedSettings.speed, formatter: decimalFormatter)
                    .frame(width: 38)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("seconds")
            }

            HStack {
                Text("Blur amount")
                    .layoutPriority(1)
                Spacer()
                Slider(value: $storedSettings.blur, in: 0 ... 1.0, step: 0.05)
                TextField("", value: $storedSettings.blur, formatter: decimalFormatter)
                    .frame(width: 38)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Text("amount")
            }
        }
        .onAppear {
            setupColorDebounce()
        }
    }

    private func colorShape(for hexColor: String, index: Int) -> some View {
        Circle()
            .fill(Color(hex: hexColor))
            .frame(width: 30, height: 30)
            .overlay(
                Circle()
                    .stroke(editingIndex == index ? Color.white : Color.clear, lineWidth: 2)
            )
            .onTapGesture {
                editingColor = hexColor
                editingIndex = index
                tempColor = Color(hex: hexColor)
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
        MessageUtil.showMessage(
            title: "Cannot Remove Color",
            message: "Minimum number of colors reached."
        ) { action in
            switch action {
            case .ok:
                print("User acknowledged the minimum colors alert")
            case .cancel:
                print("User cancelled the minimum colors alert")
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
