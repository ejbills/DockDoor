//
//  ReadModifier.swift
//  OpenArtemis
//
//  Created by Ethan Bills on 1/1/24.
//

import SwiftUI

struct HiddenModifier: ViewModifier {
    let isHidden: Bool
    func body(content: Content) -> some View {
        content
            .opacity(isHidden ? 0.55 : 1)
    }
}

extension View {
    func markHidden(isHidden: Bool) -> some View {
        self.modifier(HiddenModifier(isHidden: isHidden))
    }
}
