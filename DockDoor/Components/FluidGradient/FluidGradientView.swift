import AppKit
import Combine
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

public typealias SystemColor = NSColor
public typealias SystemView = NSView

/// A system view that presents an animated gradient with ``CoreAnimation``
public class FluidGradientView: NSView {
    var speed: CGFloat

    let baseLayer = ResizableLayer()
    let highlightLayer = ResizableLayer()

    var cancellables = Set<AnyCancellable>()
    var timerCancellable: AnyCancellable?

    weak var delegate: FluidGradientDelegate?

    init(blobs: [Color] = [],
         highlights: [Color] = [],
         speed: CGFloat = 1.0)
    {
        self.speed = speed
        super.init(frame: .zero)

        if let compositingFilter = CIFilter(name: "CIOverlayBlendMode") {
            highlightLayer.compositingFilter = compositingFilter
        }

        layer = ResizableLayer()
        wantsLayer = true
        postsFrameChangedNotifications = true

        layer?.delegate = self
        baseLayer.delegate = self
        highlightLayer.delegate = self

        layer?.addSublayer(baseLayer)
        layer?.addSublayer(highlightLayer)

        create(blobs, layer: baseLayer)
        create(highlights, layer: highlightLayer)

        setupNotifications()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopAnimationTimer()
        cancellables.removeAll()
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .compactMap { $0.object as? NSWindow }
            .filter { [weak self] window in window == self?.window }
            .sink { [weak self] _ in self?.startAnimationTimer() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)
            .compactMap { $0.object as? NSWindow }
            .filter { [weak self] window in window == self?.window }
            .sink { [weak self] _ in self?.stopAnimationTimer() }
            .store(in: &cancellables)
    }

    /// Create blobs and add to specified layer
    public func create(_ colors: [Color], layer: CALayer) {
        // Remove blobs at the end if colors are removed
        let count = layer.sublayers?.count ?? 0
        let removeCount = count - colors.count
        if removeCount > 0 {
            layer.sublayers?.removeLast(removeCount)
        }

        for (index, color) in colors.enumerated() {
            if index < count {
                if let existing = layer.sublayers?[index] as? BlobLayer {
                    existing.set(color: color)
                }
            } else {
                layer.addSublayer(BlobLayer(color: color))
            }
        }
    }

    /// Update sublayers and set speed and blur levels
    public func update(speed: CGFloat) {
        stopAnimationTimer()
        self.speed = speed
        startAnimationTimer()
    }

    /// Compute and update new blur value
    private func updateBlur() {
        delegate?.updateBlur(min(frame.width, frame.height))
    }

    private func startAnimationTimer() {
        stopAnimationTimer()
        guard speed > 0, window?.isVisible == true, !window!.isMiniaturized else { return }

        timerCancellable = Timer.publish(every: 1.0 / speed, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.animateLayers()
            }
    }

    private func stopAnimationTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func animateLayers() {
        guard let window, window.isVisible, !window.isMiniaturized else { return }

        let layers = (baseLayer.sublayers ?? []) + (highlightLayer.sublayers ?? [])
        for layer in layers {
            if let layer = layer as? BlobLayer {
                layer.animate(speed: speed)
            }
        }
    }

    // MARK: - NSView Overrides

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let scale = window?.backingScaleFactor ?? 2
        layer?.contentsScale = scale
        baseLayer.contentsScale = scale
        highlightLayer.contentsScale = scale

        updateBlur()

        if window != nil {
            startAnimationTimer()
        } else {
            stopAnimationTimer()
        }
    }

    override public func viewDidHide() {
        super.viewDidHide()
        stopAnimationTimer()
    }

    override public func viewDidUnhide() {
        super.viewDidUnhide()
        startAnimationTimer()
    }

    override public func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        updateBlur()
    }
}

protocol FluidGradientDelegate: AnyObject {
    func updateBlur(_ value: CGFloat)
}

extension FluidGradientView: CALayerDelegate, NSViewLayerContentScaleDelegate {
    public func layer(_ layer: CALayer,
                      shouldInheritContentsScale newScale: CGFloat,
                      from window: NSWindow) -> Bool
    {
        true
    }
}
