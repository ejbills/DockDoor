import Defaults
import ImageIO
import SwiftUI

enum SettingsMockPreviewContext {
    case dock
    case windowSwitcher
    case cmdTab

    var dockPosition: DockPosition {
        switch self {
        case .dock: .bottom
        case .windowSwitcher: .bottom
        case .cmdTab: .cmdTab
        }
    }

    var windowSwitcherActive: Bool {
        switch self {
        case .dock, .cmdTab: false
        case .windowSwitcher: true
        }
    }
}

struct SettingsMockPreview: View {
    let context: SettingsMockPreviewContext
    let maxHeight: CGFloat

    @StateObject private var coordinator: PreviewStateCoordinator

    @State private var wallpaperImage: NSImage? = SettingsWallpaper.cached

    init(context: SettingsMockPreviewContext, maxHeight: CGFloat = 200) {
        self.context = context
        self.maxHeight = maxHeight
        // Inside the autoclosure so the coordinator is built once, not on every redraw.
        _coordinator = StateObject(wrappedValue: Self.makeCoordinator(
            windows: Self.mockWindows,
            context: context
        ))
    }

    var body: some View {
        if !coordinator.windows.isEmpty {
            WindowPreviewHoverContainer(
                appName: "DockDoor (\u{2022}\u{203F}\u{2022})",
                onWindowTap: nil,
                dockPosition: context.dockPosition,
                mouseLocation: .zero,
                bestGuessMonitor: NSScreen.main!,
                dockItemElement: nil,
                windowSwitcherCoordinator: coordinator,
                mockPreviewActive: true,
                updateAvailable: false,
                hasScreenRecordingPermission: true
            )
            .allowsHitTesting(false)
            .modifier(ScaledToFit(maxHeight: maxHeight))
            .background {
                GeometryReader { proxy in
                    if let wallpaperImage {
                        Image(nsImage: wallpaperImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [Color(nsColor: .controlAccentColor).opacity(0.35), .teal.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onAppear {
                SettingsWallpaper.load { wallpaperImage = $0 }
            }
        }
    }

    private static let mockWindows: [WindowInfo] = generateMockWindows()

    private static func generateMockWindows(count: Int = 2) -> [WindowInfo] {
        guard let baseNSImage = NSImage(named: "WindowsXP") else { return [] }

        let pid = NSRunningApplication.current.processIdentifier
        let dummyAXElement = unsafeBitCast(kCFNull, to: AXUIElement.self)
        let rotationAngles: [CGFloat] = [0, 90, 180, 270]
        let aspectRatios: [(CGFloat, CGFloat)] = [(300, 200), (200, 300), (400, 200), (180, 320)]

        var windows: [WindowInfo] = []
        for i in 0 ..< count {
            var image = baseNSImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            image = image?.rotated(by: rotationAngles[i % rotationAngles.count]) ?? image

            if image == nil {
                image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)?
                    .cgImage(forProposedRect: nil, context: nil, hints: nil)
            }

            let ratio = aspectRatios[i % aspectRatios.count]
            let provider = MockPreviewWindow(
                windowID: CGWindowID(i + 1),
                frame: CGRect(x: CGFloat(100 * (i + 1)), y: 100, width: ratio.0, height: ratio.1),
                title: "Window \(i + 1)",
                owningApplicationBundleIdentifier: "com.example.preview",
                owningApplicationProcessID: pid + pid_t(i + 1),
                isOnScreen: true,
                windowLayer: 0
            )
            windows.append(WindowInfo(
                windowProvider: provider,
                app: .current,
                image: image,
                axElement: dummyAXElement,
                appAxElement: dummyAXElement,
                closeButton: dummyAXElement,
                lastAccessedTime: Date(),
                isMinimized: false,
                isHidden: false
            ))
        }
        return windows
    }

    private static func makeCoordinator(windows: [WindowInfo], context: SettingsMockPreviewContext) -> PreviewStateCoordinator {
        let coordinator = PreviewStateCoordinator()
        coordinator.setWindows(
            windows,
            dockPosition: context.dockPosition,
            bestGuessMonitor: NSScreen.main!,
            isMockPreviewActive: true
        )
        coordinator.windowSwitcherActive = context.windowSwitcherActive
        if !windows.isEmpty {
            coordinator.setIndex(to: 0)
        }
        return coordinator
    }
}

/// Sizes come from GeometryReader: preference keys don't update inside a grouped Form row.
private struct ScaledToFit: ViewModifier {
    let maxHeight: CGFloat
    @State private var contentSize: CGSize = .zero
    @State private var availableWidth: CGFloat = 0

    private var scale: CGFloat {
        guard contentSize.width > 0, contentSize.height > 0, availableWidth > 0 else { return 1 }
        return min(1, availableWidth / contentSize.width, maxHeight / contentSize.height)
    }

    func body(content: Content) -> some View {
        Color.clear
            .frame(height: contentSize == .zero ? maxHeight : contentSize.height * scale)
            .frame(maxWidth: .infinity)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { availableWidth = proxy.size.width }
                        .onChange(of: proxy.size.width) { availableWidth = $0 }
                }
            }
            .overlay {
                content
                    // The container draws its header and cards slightly past its own bounds.
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                    .fixedSize()
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onAppear { contentSize = proxy.size }
                                .onChange(of: proxy.size) { contentSize = $0 }
                        }
                    }
                    .scaleEffect(scale)
            }
    }
}

/// Decoded once off the main thread as a thumbnail; a full-size decode takes ~0.6s.
@MainActor
private enum SettingsWallpaper {
    private static var cachedURL: URL?
    private(set) static var cached: NSImage?

    static func load(completion: @escaping (NSImage?) -> Void) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first,
              let url = NSWorkspace.shared.desktopImageURL(for: screen)
        else { return completion(nil) }
        if url == cachedURL, let cached {
            return completion(cached)
        }

        // Utility: ImageIO decodes on default-QoS threads, and waiting on them from higher is an inversion.
        DispatchQueue.global(qos: .utility).async {
            let image = thumbnail(at: url, maxPixelSize: 1200)
            DispatchQueue.main.async {
                cachedURL = url
                cached = image
                completion(image)
            }
        }
    }

    private nonisolated static func thumbnail(at url: URL, maxPixelSize: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
