//
//  UIExtensions.swift
//  DockDoor
//
//  Created by Igor Marcossi on 14/06/24.
//

import SwiftUI

struct DockStyleModifier: ViewModifier {
    let cornerRadius: Double

    func body(content: Content) -> some View {
        content
            .background {
                BlurView()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(.dockInnerDarkBorder.opacity(0.39), lineWidth: 1)
                            .blendMode(.plusLighter)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius + 1, style: .continuous)
                            .stroke(.black.opacity(0.2), lineWidth: 1)
                            .padding(-1)
                    }
            }
            .padding(2)
    }
}

extension View {
    func dockStyle(cornerRadius: Double = 19) -> some View {
        modifier(DockStyleModifier(cornerRadius: cornerRadius))
    }
}
