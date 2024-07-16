//
//  FullSizePreviewView.swift
//  DockDoor
//
//  Created by Ethan Bills on 7/11/24.
//

import SwiftUI
import Defaults

struct FullSizePreviewView: View {
    let window: Window
    let maxSize: CGSize
    
    @Default(.uniformCardRadius) var uniformCardRadius
    
    var body: some View {
        VStack(alignment: .center) {
            Group {
                HStack(alignment: .center) {
                    if let image = window.image {
                        Image(decorative: image, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .modifier(FluidGradientBorder(cornerRadius: 6, lineWidth: 2))
                    }
                }
            }
        }
        .frame(idealHeight: maxSize.height)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.clear.shadow(.drop(color: .black.opacity(0.25), radius: 8, y: 4)))
        }
        .clipShape(uniformCardRadius ? AnyShape(RoundedRectangle(cornerRadius: 6, style: .continuous)) : AnyShape(Rectangle()))
        .padding(.all, 24)
        .dockStyle(cornerRadius: 16)
    }
}
