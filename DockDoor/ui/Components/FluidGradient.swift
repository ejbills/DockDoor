//
//  FluidGradient.swift
//  DockDoor
//
//  Created by Ethan Bills on 7/11/24.
//

import SwiftUI
import FluidGradient

func fluidGradient() -> some View {
    FluidGradient(
        blobs: [.purple, .blue, .green, .yellow, .red, .purple].shuffled(),
        highlights: [.red, .orange, .pink, .blue, .purple].shuffled(),
        speed: 0.45,
        blur: 0.75
    )
}

struct FluidGradientBorder: ViewModifier {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                fluidGradient()
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(lineWidth: lineWidth)
                    )
            )
    }
}
