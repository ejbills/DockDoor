import Cocoa
import Defaults
import ScreenCaptureKit
import SwiftUI

struct LivePreviewImage: View {
    let windowID: CGWindowID
    let fallbackImage: CGImage?
    let quality: LivePreviewQuality
    let frameRate: LivePreviewFrameRate

    @StateObject private var capture: WindowLiveCapture

    init(windowID: CGWindowID, fallbackImage: CGImage?, quality: LivePreviewQuality = .high, frameRate: LivePreviewFrameRate = .fps30) {
        self.windowID = windowID
        self.fallbackImage = fallbackImage
        self.quality = quality
        self.frameRate = frameRate
        _capture = StateObject(wrappedValue: WindowLiveCapture(windowID: windowID, quality: quality, frameRate: frameRate))
    }

    var body: some View {
        Group {
            if let image = capture.capturedImage ?? fallbackImage {
                Image(decorative: image, scale: 1.0)
                    .resizable()
            }
        }
        .task {
            await capture.startCapture()
        }
    }
}

@MainActor
class WindowLiveCapture: NSObject, ObservableObject {
    @Published var capturedImage: CGImage?

    private let windowID: CGWindowID
    private let quality: LivePreviewQuality
    private let frameRate: LivePreviewFrameRate
    private var stream: SCStream?
    private var streamOutput: StreamOutput?

    init(windowID: CGWindowID, quality: LivePreviewQuality = .high, frameRate: LivePreviewFrameRate = .fps30) {
        self.windowID = windowID
        self.quality = quality
        self.frameRate = frameRate
        super.init()
    }

    func startCapture() async {
        guard stream == nil else { return }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                return
            }
            await startStream(for: scWindow)
        } catch {}
    }

    private func startStream(for window: SCWindow) async {
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let config = SCStreamConfiguration()

        let backingScaleFactor = Int(NSScreen.main?.backingScaleFactor ?? 2.0)
        let windowWidth = Int(window.frame.width)
        let windowHeight = Int(window.frame.height)

        // Use instance quality and frame rate
        if quality.useFullResolution {
            let effectiveScale = quality == .retina || quality == .native ? 2 : backingScaleFactor
            if quality.maxDimension > 0 {
                let maxDim = quality.maxDimension
                if windowWidth > windowHeight {
                    config.width = min(maxDim, windowWidth) * effectiveScale
                    config.height = Int(Double(config.width) * Double(windowHeight) / Double(windowWidth))
                } else {
                    config.height = min(maxDim, windowHeight) * effectiveScale
                    config.width = Int(Double(config.height) * Double(windowWidth) / Double(windowHeight))
                }
            } else {
                // Native - no limit
                config.width = windowWidth * effectiveScale
                config.height = windowHeight * effectiveScale
            }
        } else {
            let maxDim = quality.maxDimension
            let aspectRatio = Double(windowWidth) / Double(windowHeight)
            if aspectRatio > 1 {
                config.width = min(maxDim, windowWidth * backingScaleFactor)
                config.height = Int(Double(config.width) / aspectRatio)
            } else {
                config.height = min(maxDim, windowHeight * backingScaleFactor)
                config.width = Int(Double(config.height) * aspectRatio)
            }
        }

        config.minimumFrameInterval = CMTime(value: 1, timescale: frameRate.frameRate)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.queueDepth = quality == .native || quality == .retina ? 5 : 3
        config.scalesToFit = true

        do {
            let newStream = SCStream(filter: filter, configuration: config, delegate: nil)

            let output = StreamOutput(windowID: windowID) { [weak self] image in
                Task { @MainActor in
                    self?.capturedImage = image
                }
            }

            try newStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
            try await newStream.startCapture()

            stream = newStream
            streamOutput = output
        } catch {}
    }

    func stopCapture() async {
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        streamOutput = nil
        capturedImage = nil
    }
}

private class StreamOutput: NSObject, SCStreamOutput {
    let windowID: CGWindowID
    let onFrame: (CGImage) -> Void

    init(windowID: CGWindowID, onFrame: @escaping (CGImage) -> Void) {
        self.windowID = windowID
        self.onFrame = onFrame
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        guard let cgImage = context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            return
        }

        onFrame(cgImage)
    }
}
