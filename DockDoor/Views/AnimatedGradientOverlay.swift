//
//  AnimatedGradientOverlay.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/12/24.
//

import SwiftUI

struct AnimatedGradientOverlay: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.purple, .blue, .green, .yellow, .red, .purple].shuffled()),
                startPoint: animate ? .topLeading : .bottomTrailing,
                endPoint: animate ? .bottomTrailing : .topLeading
            )
            .blendMode(.overlay)
            .blur(radius: 50)
            
            AngularGradient(
                gradient: Gradient(colors: [.red, .orange, .pink, .blue, .purple].shuffled()),
                center: .center,
                startAngle: .degrees(animate ? 0 : 360),
                endAngle: .degrees(animate ? 360 : 0)
            )
            .blendMode(.overlay)
            .opacity(0.5)
            .blur(radius: 50)
        }
        .animation(
            Animation.linear(duration: 5.0)
                .repeatForever(autoreverses: true),
            value: animate
        )
        .onAppear {
            self.animate = true
        }
        .opacity(0.3)
        .blendMode(.overlay)
    }
}

