import Defaults
import SwiftUI

enum PreviewContext: String, CaseIterable, Identifiable {
    case dock, windowSwitcher, cmdTab
    var id: String { rawValue }
    var displayName: LocalizedStringKey {
        switch self {
        case .dock: "Dock Previews"
        case .windowSwitcher: "Window Switcher"
        case .cmdTab: "Cmd+Tab"
        }
    }
}

// MARK: - Mock Data Generation

extension AppearanceSettingsView {
    private static func generateMockWindowsForPreview(count: Int = 2) -> [WindowInfo] {
        guard let baseNSImage = NSImage(named: "WindowsXP") else {
            return []
        }

        let pid = NSRunningApplication.current.processIdentifier
        var mockWindows: [WindowInfo] = []
        let geometricRotationAngles: [CGFloat] = [0, 90, 180, 270]

        for i in 0 ..< count {
            let mockNsApp = NSRunningApplication.current
            let dummyAXElement = unsafeBitCast(kCFNull, to: AXUIElement.self)

            var processedImage: CGImage? = baseNSImage.cgImage(forProposedRect: nil, context: nil, hints: nil)

            let angleIndex = i % geometricRotationAngles.count
            let deterministicGeometricAngle = geometricRotationAngles[angleIndex]
            processedImage = processedImage?.rotated(by: deterministicGeometricAngle) ?? processedImage

            if processedImage == nil {
                processedImage = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error processing image")?
                    .cgImage(forProposedRect: nil, context: nil, hints: nil)
            }

            let aspectRatios: [(width: CGFloat, height: CGFloat)] = [
                (300, 200),
                (200, 300),
                (400, 200),
                (180, 320),
            ]
            let aspectRatio = aspectRatios[i % aspectRatios.count]

            let mockWindowProvider = MockPreviewWindow(
                windowID: CGWindowID(i + 1),
                frame: CGRect(x: CGFloat(100 * (i + 1)), y: 100, width: aspectRatio.width, height: aspectRatio.height),
                title: "Window \(i + 1)",
                owningApplicationBundleIdentifier: "com.example.preview",
                owningApplicationProcessID: pid + pid_t(i + 1),
                isOnScreen: true,
                windowLayer: 0
            )
            mockWindows.append(
                WindowInfo(
                    windowProvider: mockWindowProvider,
                    app: mockNsApp,
                    image: processedImage,
                    axElement: dummyAXElement,
                    appAxElement: dummyAXElement,
                    closeButton: dummyAXElement,
                    lastAccessedTime: Date(),
                    isMinimized: false,
                    isHidden: false
                )
            )
        }
        return mockWindows
    }

    static func getMockCoordinator(windows: [WindowInfo], windowSwitcherActive: Bool, dockPosition: DockPosition, bestGuessMonitor: NSScreen) -> PreviewStateCoordinator {
        let coordinator = PreviewStateCoordinator()
        coordinator.setWindows(windows, dockPosition: dockPosition, bestGuessMonitor: bestGuessMonitor, isMockPreviewActive: true)
        coordinator.windowSwitcherActive = windowSwitcherActive
        if !windows.isEmpty {
            coordinator.setIndex(to: 0)
        }
        return coordinator
    }
}

struct AppearanceSettingsView: View {
    @Default(.disableImagePreview) var disableImagePreview
    @Default(.allowDynamicImageSizing) var allowDynamicImageSizing

    @StateObject private var permissionsChecker = PermissionsChecker()

    @State private var showAdvancedAppearanceSettings: Bool = false
    @State private var selectedPreviewContext: PreviewContext = .dock
    @State private var mockAppNameForPreview: String = "DockDoor (•‿•)"
    @StateObject private var mockWindowSwitcherCoordinator: PreviewStateCoordinator
    @StateObject private var mockDockPreviewCoordinator: PreviewStateCoordinator

    private let advancedAppearanceSettingsSectionID = "advancedAppearanceSettingsSection"

    init() {
        let initialMockWindows = AppearanceSettingsView.generateMockWindowsForPreview()

        _mockDockPreviewCoordinator = StateObject(wrappedValue: AppearanceSettingsView.getMockCoordinator(
            windows: initialMockWindows,
            windowSwitcherActive: false,
            dockPosition: .bottom,
            bestGuessMonitor: NSScreen.main!
        ))
        _mockWindowSwitcherCoordinator = StateObject(wrappedValue: AppearanceSettingsView.getMockCoordinator(
            windows: initialMockWindows,
            windowSwitcherActive: true,
            dockPosition: .bottom,
            bestGuessMonitor: NSScreen.main!
        ))
    }

    var body: some View {
        ScrollViewReader { proxy in
            BaseSettingsView {
                VStack(alignment: .leading, spacing: 16) {
                    if !permissionsChecker.screenRecordingPermission {
                        CompactModeWarningBanner(
                            hasScreenRecordingPermission: permissionsChecker.screenRecordingPermission,
                            disableImagePreview: disableImagePreview
                        )
                    }

                    WindowSizeSettingsSection(onDynamicSizingChanged: {
                        let dockPosition = DockPosition.bottom
                        let monitor = NSScreen.main!
                        mockDockPreviewCoordinator.recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: monitor, isMockPreviewActive: true)
                        mockWindowSwitcherCoordinator.recomputeAndPublishDimensions(dockPosition: dockPosition, bestGuessMonitor: monitor, isMockPreviewActive: true)
                    })

                    GeneralAppearanceSection()

                    CompactModeSection(hasScreenRecordingPermission: permissionsChecker.screenRecordingPermission)

                    previewContextPicker

                    previewContainer

                    contextSettingsSection

                    advancedSettingsToggle(proxy: proxy)

                    if showAdvancedAppearanceSettings {
                        AdvancedAppearanceSection()
                            .id(advancedAppearanceSettingsSectionID)
                    }
                }
            }
        }
    }

    // MARK: - Preview Context Picker

    private var previewContextPicker: some View {
        VStack {
            Picker("", selection: $selectedPreviewContext.animation(Animation.smooth)) {
                ForEach(PreviewContext.allCases) { context in
                    Text(context.displayName).tag(context)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Preview Container

    private var previewContainer: some View {
        VStack {
            let currentCoordinator: PreviewStateCoordinator = switch selectedPreviewContext {
            case .dock, .cmdTab:
                mockDockPreviewCoordinator
            case .windowSwitcher:
                mockWindowSwitcherCoordinator
            }
            let currentDockPosition: DockPosition = switch selectedPreviewContext {
            case .dock:
                .bottom
            case .windowSwitcher:
                .bottom
            case .cmdTab:
                .cmdTab
            }
            if !currentCoordinator.windows.isEmpty {
                WindowPreviewHoverContainer(
                    appName: mockAppNameForPreview,
                    onWindowTap: nil,
                    dockPosition: currentDockPosition,
                    mouseLocation: .zero,
                    bestGuessMonitor: NSScreen.main!,
                    dockItemElement: nil,
                    windowSwitcherCoordinator: currentCoordinator,
                    mockPreviewActive: true,
                    updateAvailable: false,
                    hasScreenRecordingPermission: true
                )
                .allowsHitTesting(false)
            } else {
                Text("Loading preview...")
                    .frame(minHeight: 150, maxHeight: 250)
            }
        }
    }

    // MARK: - Context Settings Section

    private var contextSettingsSection: some View {
        SettingsGroup(header: contextSettingsLabel) {
            switch selectedPreviewContext {
            case .dock:
                DockPreviewAppearanceSection()
            case .windowSwitcher:
                WindowSwitcherAppearanceSection()
            case .cmdTab:
                CmdTabAppearanceSection()
            }
        }
    }

    private var contextSettingsLabel: LocalizedStringKey {
        switch selectedPreviewContext {
        case .dock:
            "Dock Preview Settings"
        case .windowSwitcher:
            "Window Switcher Settings"
        case .cmdTab:
            "Cmd+Tab Settings"
        }
    }

    // MARK: - Advanced Settings Toggle

    private func advancedSettingsToggle(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .center) {
            Text("Fine-tune visual details and layout options.")
                .font(.footnote)
                .foregroundColor(.gray)
            HStack {
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.1)) {
                        showAdvancedAppearanceSettings.toggle()
                        if showAdvancedAppearanceSettings {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.smooth(duration: 0.1)) {
                                    proxy.scrollTo(advancedAppearanceSettingsSectionID, anchor: .top)
                                }
                            }
                        }
                    }
                } label: {
                    Label(showAdvancedAppearanceSettings ? "Hide Advanced Settings" : "Show Advanced Settings", systemImage: showAdvancedAppearanceSettings ? "chevron.up.circle" : "chevron.down.circle")
                }
                .buttonStyle(AccentButtonStyle())
                Spacer()
            }
        }
    }
}
