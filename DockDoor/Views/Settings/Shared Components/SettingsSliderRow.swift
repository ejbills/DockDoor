import SwiftUI

struct SettingsSliderRow<T: BinaryFloatingPoint>: View where T.Stride: BinaryFloatingPoint {
    let title: LocalizedStringKey
    @Binding var value: T
    let range: ClosedRange<T>
    var defaultValue: T?
    var unit = ""
    var step: T.Stride = 1
    var decimals = 0
    var valueText: ((T) -> String)?
    var onEditingChanged: ((Bool) -> Void)?

    private var effectiveDecimals: Int {
        guard decimals == 0, Double(step) < 1 else { return decimals }
        return Double(step) < 0.1 ? 2 : 1
    }

    private var displayValue: String {
        if let valueText {
            return valueText(value)
        }
        return String(format: "%.\(effectiveDecimals)f", Double(value)) + unit
    }

    private var snappedValue: Binding<T> {
        Binding {
            value
        } set: { newValue in
            let stepSize = T(step)
            guard stepSize > 0 else { return value = newValue }
            let snapped = range.lowerBound + ((newValue - range.lowerBound) / stepSize).rounded() * stepSize
            value = min(max(snapped, range.lowerBound), range.upperBound)
        }
    }

    private var isModified: Bool {
        guard let defaultValue else { return false }
        return abs(Double(value) - Double(defaultValue)) > 0.01
    }

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Slider(value: snappedValue, in: range) { isEditing in
                    onEditingChanged?(isEditing)
                }
                .labelsHidden()
                .frame(width: 180)

                Text(displayValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 72, alignment: .trailing)

                SettingsResetButton(isModified: isModified) {
                    guard let defaultValue else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        value = defaultValue
                    }
                }
                .frame(width: 16)
            }
        } label: {
            Text(title)
        }
    }
}
