import Cocoa
import Defaults
import ScreenCaptureKit

@MainActor
class LiveWindowCapture: NSObject, ObservableObject {
    static let shared = LiveWindowCapture()

    @Published var capturedImages: [CGWindowID: CGImage] = [:]

    private var streams: [CGWindowID: SCStream] = [:]
    private var streamOutputs: [CGWindowID: StreamOutput] = [:]
    private var isCapturing = false

    var isEnabled: Bool {
        Defaults[.enableLivePreview]
    }

    override private init() {
        super.init()
    }

    func startCapture(windowIDs: [CGWindowID]) async {
        guard Defaults[.enableLivePreview] else { return }

        await stopAllCaptures()
        isCapturing = true

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)

            for windowID in windowIDs {
                guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                    continue
                }
                await startStreamForWindow(scWindow)
            }
        } catch {}
    }

    private func startStreamForWindow(_ window: SCWindow) async {
        let windowID = window.windowID
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let quality = Defaults[.livePreviewQuality]
        let frameRate = Defaults[.livePreviewFrameRate]

        let config = SCStreamConfiguration()

        let windowWidth = Int(window.frame.width)
        let windowHeight = Int(window.frame.height)

        if quality.useFullResolution {
            config.width = windowWidth * quality.scaleFactor
            config.height = windowHeight * quality.scaleFactor
        } else {
            config.width = min(640, windowWidth)
            config.height = min(360, windowHeight)
        }

        config.minimumFrameInterval = CMTime(value: 1, timescale: frameRate.frameRate)
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = false
        config.queueDepth = quality == .retina ? 5 : 3
        config.scalesToFit = false

        do {
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)

            let output = StreamOutput(windowID: windowID) { [weak self] image in
                Task { @MainActor in
                    self?.capturedImages[windowID] = image
                }
            }

            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
            try await stream.startCapture()

            streams[windowID] = stream
            streamOutputs[windowID] = output
        } catch {}
    }

    func stopAllCaptures() async {
        isCapturing = false

        for (_, stream) in streams {
            try? await stream.stopCapture()
        }

        streams.removeAll()
        streamOutputs.removeAll()
        capturedImages.removeAll()
    }

    func stopCapture(windowID: CGWindowID) async {
        if let stream = streams[windowID] {
            try? await stream.stopCapture()
            streams.removeValue(forKey: windowID)
            streamOutputs.removeValue(forKey: windowID)
            capturedImages.removeValue(forKey: windowID)
        }
    }

    func getImage(for windowID: CGWindowID) -> CGImage? {
        capturedImages[windowID]
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
