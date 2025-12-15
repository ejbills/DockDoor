import Cocoa
import Defaults
import ScreenCaptureKit
import SwiftUI
import VideoToolbox

struct LivePreviewImage: View {
    let windowID: CGWindowID
    let fallbackImage: CGImage?
    let quality: LivePreviewQuality
    let frameRate: LivePreviewFrameRate

    var body: some View {
        let keepAlive = Defaults[.livePreviewStreamKeepAlive]

        if keepAlive != 0 {
            LivePreviewImageCached(windowID: windowID, fallbackImage: fallbackImage, quality: quality, frameRate: frameRate)
        } else {
            LivePreviewImageFresh(windowID: windowID, fallbackImage: fallbackImage, quality: quality, frameRate: frameRate)
        }
    }
}

private struct LivePreviewImageCached: View {
    let windowID: CGWindowID
    let fallbackImage: CGImage?
    let quality: LivePreviewQuality
    let frameRate: LivePreviewFrameRate

    @ObservedObject private var capture: WindowLiveCapture

    init(windowID: CGWindowID, fallbackImage: CGImage?, quality: LivePreviewQuality, frameRate: LivePreviewFrameRate) {
        self.windowID = windowID
        self.fallbackImage = fallbackImage
        self.quality = quality
        self.frameRate = frameRate
        capture = LiveCaptureManager.shared.getCapture(windowID: windowID, quality: quality, frameRate: frameRate)
    }

    var body: some View {
        Group {
            if let image = capture.capturedImage ?? capture.lastFrame ?? fallbackImage {
                Image(decorative: image, scale: 1.0)
                    .resizable()
            }
        }
        .task {
            await capture.startCapture()
        }
    }
}

private struct LivePreviewImageFresh: View {
    let windowID: CGWindowID
    let fallbackImage: CGImage?
    let quality: LivePreviewQuality
    let frameRate: LivePreviewFrameRate

    @StateObject private var capture: WindowLiveCapture

    init(windowID: CGWindowID, fallbackImage: CGImage?, quality: LivePreviewQuality, frameRate: LivePreviewFrameRate) {
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
final class LiveCaptureManager {
    static let shared = LiveCaptureManager()
    private var captures: [CGWindowID: WindowLiveCapture] = [:]
    private var stopGeneration = 0

    private init() {}

    func panelOpened() {
        stopGeneration += 1
    }

    func panelClosed() async {
        let keepAlive = Defaults[.livePreviewStreamKeepAlive]

        if keepAlive < 0 {
            return
        }

        if keepAlive == 0 {
            await stopAllStreams()
            return
        }

        stopGeneration += 1
        let generationAtClose = stopGeneration

        try? await Task.sleep(nanoseconds: UInt64(keepAlive) * 1_000_000_000)

        guard stopGeneration == generationAtClose else { return }

        await stopAllStreams()
    }

    func getCapture(windowID: CGWindowID, quality: LivePreviewQuality, frameRate: LivePreviewFrameRate) -> WindowLiveCapture {
        if let existing = captures[windowID] {
            return existing
        }

        let capture = WindowLiveCapture(windowID: windowID, quality: quality, frameRate: frameRate)
        captures[windowID] = capture
        return capture
    }

    func requestStop(windowID: CGWindowID) async {
        guard let capture = captures[windowID] else { return }
        await capture.requestStop()
    }

    func remove(windowID: CGWindowID) {
        captures.removeValue(forKey: windowID)
    }

    func stopAllStreams() async {
        for capture in captures.values {
            await capture.stopAndCleanup()
        }
        captures.removeAll()
    }
}

@MainActor
final class WindowLiveCapture: ObservableObject {
    @Published var capturedImage: CGImage?

    private let windowID: CGWindowID
    private let quality: LivePreviewQuality
    private let frameRate: LivePreviewFrameRate
    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private var stopGeneration = 0
    private(set) var lastFrame: CGImage?

    init(windowID: CGWindowID, quality: LivePreviewQuality, frameRate: LivePreviewFrameRate) {
        self.windowID = windowID
        self.quality = quality
        self.frameRate = frameRate
    }

    func startCapture() async {
        stopGeneration += 1
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

        if #available(macOS 14.0, *) {
            config.captureResolution = .best
        }

        if #available(macOS 15.0, *) {
            config.captureDynamicRange = .hdrLocalDisplay
            config.colorSpaceName = CGColorSpace.displayP3 as CFString
        }

        do {
            let newStream = SCStream(filter: filter, configuration: config, delegate: nil)

            let output = StreamOutput { [weak self] image in
                Task { @MainActor in
                    self?.lastFrame = image
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

    func requestStop() async {
        let keepAlive = Defaults[.livePreviewStreamKeepAlive]

        if keepAlive < 0 {
            return
        }

        if keepAlive == 0 {
            await stopAndCleanup()
            return
        }

        stopGeneration += 1
        let generationAtStop = stopGeneration

        try? await Task.sleep(nanoseconds: UInt64(keepAlive) * 1_000_000_000)

        guard stopGeneration == generationAtStop else { return }

        await stopAndCleanup()
    }

    func stopCapture() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
        streamOutput = nil
        capturedImage = nil
    }

    func stopAndCleanup() async {
        guard let stream else { return }
        streamOutput = nil
        self.stream = nil
        capturedImage = nil
        lastFrame = nil
        try? await stream.stopCapture()
        LiveCaptureManager.shared.remove(windowID: windowID)
    }

    func forceStopNonBlocking() {
        guard let stream else { return }
        let streamToStop = stream
        self.stream = nil
        streamOutput = nil
        Task.detached {
            try? await streamToStop.stopCapture()
        }
    }
}

private class StreamOutput: NSObject, SCStreamOutput {
    private let onFrame: (CGImage) -> Void

    init(onFrame: @escaping (CGImage) -> Void) {
        self.onFrame = onFrame
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

        if let image = cgImage {
            onFrame(image)
        }
    }
}
