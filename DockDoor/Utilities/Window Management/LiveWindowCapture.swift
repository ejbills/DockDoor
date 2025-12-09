import Cocoa
import Defaults
import ScreenCaptureKit
import SwiftUI

struct LivePreviewImage: View {
    let windowID: CGWindowID
    let fallbackImage: CGImage?

    @StateObject private var capture: WindowLiveCapture

    init(windowID: CGWindowID, fallbackImage: CGImage?) {
        self.windowID = windowID
        self.fallbackImage = fallbackImage
        _capture = StateObject(wrappedValue: WindowLiveCapture(windowID: windowID))
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
    private var stream: SCStream?
    private var streamOutput: StreamOutput?

    init(windowID: CGWindowID) {
        self.windowID = windowID
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

        let quality = Defaults[.livePreviewQuality]
        let frameRate = Defaults[.livePreviewFrameRate]

        let config = SCStreamConfiguration()

        let backingScaleFactor = Int(NSScreen.main?.backingScaleFactor ?? 2.0)
        let windowWidth = Int(window.frame.width)
        let windowHeight = Int(window.frame.height)

        if quality.useFullResolution {
            let effectiveScale = quality == .retina ? 2 : backingScaleFactor
            config.width = windowWidth * effectiveScale
            config.height = windowHeight * effectiveScale
        } else {
            let aspectRatio = Double(windowWidth) / Double(windowHeight)
            if aspectRatio > 1 {
                config.width = min(640, windowWidth * backingScaleFactor)
                config.height = Int(Double(config.width) / aspectRatio)
            } else {
                config.height = min(480, windowHeight * backingScaleFactor)
                config.width = Int(Double(config.height) * aspectRatio)
            }
        }

        config.minimumFrameInterval = CMTime(value: 1, timescale: frameRate.frameRate)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.queueDepth = quality == .retina ? 5 : 3
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
