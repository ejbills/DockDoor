//
//  Traffic Light Buttons.swift
//  DockDoor
//
//  Created by Ethan Bills on 7/8/24.
//

import SwiftUI

struct TrafficLightButtons: View {
    let windowInfo: WindowInfo
    let onAction: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 6) {
            buttonFor(action: .quit, symbol: "power", color: .purple)
            buttonFor(action: .close, symbol: "xmark", color: .red)
            buttonFor(action: .minimize, symbol: "minus", color: .yellow)
            buttonFor(action: .toggleFullScreen, symbol: "arrow.up.left.and.arrow.down.right", color: .green)
        }
        .padding(4)
        .opacity(isHovering ? 1 : 0.25)
        .onHover { over in
            withAnimation(.snappy(duration: 0.175)) {
                isHovering = over
            }
        }
    }
    
    private func buttonFor(action: WindowAction, symbol: String, color: Color) -> some View {
        Button(action: {
            performAction(action)
            onAction()
        }) {
            ZStack {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.secondary)
                Image(systemName: "\(symbol).circle.fill")
            }
        }
        .buttonBorderShape(.roundedRectangle)
        .foregroundStyle(color)
        .buttonStyle(.plain)
        .font(.system(size: 13))
    }
    
    private func performAction(_ action: WindowAction) {
        switch action {
        case .quit:
            WindowUtil.quitApp(windowInfo: windowInfo, force: NSEvent.modifierFlags.contains(.option))
        case .close:
            WindowUtil.closeWindow(closeButton: windowInfo.closeButton!)
        case .minimize:
            WindowUtil.toggleMinimize(windowInfo: windowInfo)
        case .toggleFullScreen:
            WindowUtil.toggleFullScreen(windowInfo: windowInfo)
        }
    }
    
    private enum WindowAction {
        case quit, close, minimize, toggleFullScreen
    }
}
