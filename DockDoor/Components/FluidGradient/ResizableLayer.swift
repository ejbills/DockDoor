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

/// An implementation of ``CALayer`` that resizes its sublayers
public class ResizableLayer: CALayer {
    override init() {
        super.init()
        autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        sublayers = []
    }

    override public init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func layoutSublayers() {
        super.layoutSublayers()
        sublayers?.forEach { layer in
            layer.frame = self.frame
        }
    }
}
