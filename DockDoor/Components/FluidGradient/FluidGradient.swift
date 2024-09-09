import SwiftUI

/*
 This file is part of DockDoor, licensed under the GNU General Public License version 3 (GPL-3.0).

 This file includes code originally obtained from https://github.com/Cindori/FluidGradient, which is licensed under the MIT License.

 MIT License

 Copyright (c) 2022 Cindori

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.

 You can redistribute and/or modify this file under the terms of the GPL-3.0 License as part of this project.
 See the LICENSE file in the root directory of this project for details.
 */

public struct FluidGradient: View {
    private var blobs: [Color]
    private var highlights: [Color]
    private var speed: CGFloat
    private var blur: CGFloat

    @State var blurValue: CGFloat = 0.0

    public init(blobs: [Color],
                highlights: [Color] = [],
                speed: CGFloat = 1.0,
                blur: CGFloat = 0.75)
    {
        self.blobs = blobs
        self.highlights = highlights
        self.speed = speed
        self.blur = blur
    }

    public var body: some View {
        Representable(blobs: blobs,
                      highlights: highlights,
                      speed: speed,
                      blurValue: $blurValue)
            .blur(radius: pow(blurValue, blur))
            .accessibility(hidden: true)
            .clipped()
    }
}

typealias SystemRepresentable = NSViewRepresentable

// MARK: - Representable

extension FluidGradient {
    struct Representable: SystemRepresentable {
        var blobs: [Color]
        var highlights: [Color]
        var speed: CGFloat

        @Binding var blurValue: CGFloat

        func makeView(context: Context) -> FluidGradientView {
            context.coordinator.view
        }

        func updateView(_ view: FluidGradientView, context: Context) {
            context.coordinator.create(blobs: blobs, highlights: highlights)
            DispatchQueue.main.async {
                context.coordinator.update(speed: speed)
            }
        }

        func makeNSView(context: Context) -> FluidGradientView {
            makeView(context: context)
        }

        func updateNSView(_ view: FluidGradientView, context: Context) {
            updateView(view, context: context)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(blobs: blobs,
                        highlights: highlights,
                        speed: speed,
                        blurValue: $blurValue)
        }
    }

    class Coordinator: FluidGradientDelegate {
        var blobs: [Color]
        var highlights: [Color]
        var speed: CGFloat
        var blurValue: Binding<CGFloat>

        var view: FluidGradientView

        init(blobs: [Color],
             highlights: [Color],
             speed: CGFloat,
             blurValue: Binding<CGFloat>)
        {
            self.blobs = blobs
            self.highlights = highlights
            self.speed = speed
            self.blurValue = blurValue
            view = FluidGradientView(blobs: blobs,
                                     highlights: highlights,
                                     speed: speed)
            view.delegate = self
        }

        /// Create blobs and highlights
        func create(blobs: [Color], highlights: [Color]) {
            guard blobs != self.blobs || highlights != self.highlights else { return }
            self.blobs = blobs
            self.highlights = highlights

            view.create(blobs, layer: view.baseLayer)
            view.create(highlights, layer: view.highlightLayer)
            view.update(speed: speed)
        }

        /// Update speed
        func update(speed: CGFloat) {
            guard speed != self.speed else { return }
            self.speed = speed
            view.update(speed: speed)
        }

        func updateBlur(_ value: CGFloat) {
            blurValue.wrappedValue = value
        }
    }
}
