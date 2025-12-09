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

    init(windowID: CGWindowID, fallbackImage: CGImage?, quality: LivePreviewQuality = .high, frameRate: LivePreviewFrameRate = .fps24) {
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
        .onDisappear {
            Task { await capture.stopCapture() }
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

    init(windowID: CGWindowID, quality: LivePreviewQuality = .high, frameRate: LivePreviewFrameRate = .fps24) {
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
        } catch {
            DebugLogger.log("LiveWindowCapture: Failed to get shareable content", details: error.localizedDescription)
        }
    }

    private func startStream(for window: SCWindow) async {
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let config = SCStreamConfiguration()

        let backingScaleFactor = Int(NSScreen.main?.backingScaleFactor ?? 2.0)
        let windowWidth = Int(window.frame.width)
        let windowHeight = Int(window.frame.height)
        let maxDim = quality.maxDimension

        if quality.useFullResolution {
            let effectiveScale = quality.scaleFactor == 2 ? 2 : backingScaleFactor
            var targetWidth = windowWidth * effectiveScale
            var targetHeight = windowHeight * effectiveScale

            if maxDim > 0 {
                let aspectRatio = Double(targetWidth) / Double(targetHeight)
                if targetWidth > targetHeight {
                    targetWidth = min(targetWidth, maxDim * effectiveScale)
                    targetHeight = Int(Double(targetWidth) / aspectRatio)
                } else {
                    targetHeight = min(targetHeight, maxDim * effectiveScale)
                    targetWidth = Int(Double(targetHeight) * aspectRatio)
                }
            }

            config.width = targetWidth
            config.height = targetHeight
        } else {
            let aspectRatio = Double(windowWidth) / Double(windowHeight)
            let limitDim = maxDim > 0 ? maxDim : 640
            if aspectRatio > 1 {
                config.width = min(limitDim, windowWidth * backingScaleFactor)
                config.height = Int(Double(config.width) / aspectRatio)
            } else {
                config.height = min(limitDim, windowHeight * backingScaleFactor)
                config.width = Int(Double(config.height) * aspectRatio)
            }
        }

        config.minimumFrameInterval = CMTime(value: 1, timescale: frameRate.frameRate)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.queueDepth = quality.scaleFactor == 2 ? 5 : 3
        config.scalesToFit = true

        do {
            let newStream = SCStream(filter: filter, configuration: config, delegate: nil)

            let output = StreamOutput { [weak self] image in
                Task { @MainActor in
                    self?.capturedImage = image
                }
            }

            try newStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
            try await newStream.startCapture()

            stream = newStream
            streamOutput = output
        } catch {
            DebugLogger.log("LiveWindowCapture: Failed to start stream", details: error.localizedDescription)
        }
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
    private let context = CIContext()
    private let onFrame: (CGImage) -> Void

    init(onFrame: @escaping (CGImage) -> Void) {
        self.onFrame = onFrame
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        guard let cgImage = context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            return
        }

        onFrame(cgImage)
    }
}
