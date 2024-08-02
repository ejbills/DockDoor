//
//  DynStack.swift
//  DockDoor
//
//  Created by Igor Marcossi on 14/06/24.
//

import SwiftUI

struct DynStack<C: View>: View {
    var direction: Axis
    var spacing: Double
    @ViewBuilder var content: () -> C
    var body: some View {
        if direction == .vertical {
            VStack(spacing: spacing) {
                content()
            }
        } else {
            HStack(spacing: spacing) {
                content()
            }
        }
    }
}
