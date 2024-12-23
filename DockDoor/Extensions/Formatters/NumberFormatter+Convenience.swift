import SwiftUI

extension NumberFormatter {
    static let defaultFormatter: NumberFormatter = .init()
    static let oneDecimalFormatter: NumberFormatter = .init(style: .decimal, minimumFractionDigits: 1, maximumFractionDigits: 1)
    static let twoDecimalFormatter: NumberFormatter = .init(style: .decimal, minimumFractionDigits: 2, maximumFractionDigits: 2)
    static let percentFormatter: NumberFormatter = .init(style: .percent, minimumFractionDigits: 0, maximumFractionDigits: 0)
}

extension NumberFormatter {
    convenience init(
        style: NumberFormatter.Style = .none,
        minimumFractionDigits: Int? = nil,
        maximumFractionDigits: Int? = nil
    ) {
        self.init()
        numberStyle = style
        if let minDigits = minimumFractionDigits {
            self.minimumFractionDigits = minDigits
        }
        if let maxDigits = maximumFractionDigits {
            self.maximumFractionDigits = maxDigits
        }
    }
}
