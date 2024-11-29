import SwiftUI

func sliderSetting<T: BinaryFloatingPoint>(
    title: String,
    value: Binding<T>,
    range: ClosedRange<T>,
    step: T.Stride,
    unit: String
) -> some View where T.Stride: BinaryFloatingPoint {
    VStack(alignment: .leading, spacing: 5) {
        Text(title)
            .font(.body)
        HStack {
            Slider(
                value: value,
                in: range,
                step: step
            )
            TextField("", text: Binding(
                get: { String(describing: value.wrappedValue) },
                set: { str in
                    if let newValue = Double(str) {
                        value.wrappedValue = T(newValue)
                    }
                }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 50)
            Text(unit)
                .font(.footnote)
        }
    }
}
