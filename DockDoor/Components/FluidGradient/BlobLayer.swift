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

/// A CALayer that draws a single blob on the screen
public class BlobLayer: CAGradientLayer {
    init(color: Color) {
        super.init()

        type = .radial
        autoresizingMask = [.layerWidthSizable, .layerHeightSizable]

        // Set color
        set(color: color)

        // Center point
        let position = newPosition()
        startPoint = position

        // Radius
        let radius = newRadius()
        endPoint = position.displace(by: radius)
    }

    /// Generate a random point on the canvas
    func newPosition() -> CGPoint {
        CGPoint(x: CGFloat.random(in: 0.0 ... 1.0),
                y: CGFloat.random(in: 0.0 ... 1.0)).capped()
    }

    /// Generate a random radius for the blob
    func newRadius() -> CGPoint {
        let size = CGFloat.random(in: 0.15 ... 0.75)
        let viewRatio = frame.width / frame.height
        let safeRatio = max(viewRatio.isNaN ? 1 : viewRatio, 1)
        let ratio = safeRatio * CGFloat.random(in: 0.25 ... 1.75)
        return CGPoint(x: size,
                       y: size * ratio)
    }

    /// Animate the blob to a random point and size on screen at set speed
    func animate(speed: CGFloat) {
        guard speed > 0 else { return }

        removeAllAnimations()
        let currentLayer = presentation() ?? self

        let animation = CASpringAnimation()
        animation.mass = 10 / speed
        animation.damping = 50
        animation.duration = 1 / speed

        animation.isRemovedOnCompletion = false
        animation.fillMode = CAMediaTimingFillMode.forwards

        let position = newPosition()
        let radius = newRadius()

        // Center point
        let start = animation.copy() as! CASpringAnimation
        start.keyPath = "startPoint"
        start.fromValue = currentLayer.startPoint
        start.toValue = position

        // Radius
        let end = animation.copy() as! CASpringAnimation
        end.keyPath = "endPoint"
        end.fromValue = currentLayer.endPoint
        end.toValue = position.displace(by: radius)

        startPoint = position
        endPoint = position.displace(by: radius)

        // Opacity
        let value = Float.random(in: 0.5 ... 1)
        let opacity = animation.copy() as! CASpringAnimation
        opacity.fromValue = self.opacity
        opacity.toValue = value

        self.opacity = value

        add(opacity, forKey: "opacity")
        add(start, forKey: "startPoint")
        add(end, forKey: "endPoint")
    }

    /// Set the color of the blob
    func set(color: Color) {
        // Converted to the system color so that cgColor isn't nil
        colors = [SystemColor(color).cgColor,
                  SystemColor(color).cgColor,
                  SystemColor(color.opacity(0.0)).cgColor]
        locations = [0.0, 0.9, 1.0]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Required by the framework
    override public init(layer: Any) {
        super.init(layer: layer)
    }
}
