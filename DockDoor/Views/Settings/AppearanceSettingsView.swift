import Defaults
import SwiftUI

enum PreviewContext: String, CaseIterable, Identifiable {
    case dock, windowSwitcher
    var id: String { rawValue }
    var displayName: LocalizedStringKey {
        switch self {
        case .dock: "Dock Previews"
        case .windowSwitcher: "Window Switcher"
        }
    }
}

// MARK: - Mock Data Generation

extension AppearanceSettingsView {
    private static func generateMockWindowsForPreview(count: Int = 3) -> [WindowInfo] {
        guard let baseNSImage = NSImage(named: "WindowsXP") else {
            return []
        }

        let pid = NSRunningApplication.current.processIdentifier
        var mockWindows: [WindowInfo] = []
        let geometricRotationAngles: [CGFloat] = [0, 90, 180, 270] // Degrees

        for i in 0 ..< count {
            let mockNsApp = NSRunningApplication.current
            let dummyAXElement = unsafeBitCast(kCFNull, to: AXUIElement.self)

            var processedImage: CGImage? = baseNSImage.cgImage(forProposedRect: nil, context: nil, hints: nil)

            let angleIndex = i % geometricRotationAngles.count
            let deterministicGeometricAngle = geometricRotationAngles[angleIndex] // Degrees
            processedImage = processedImage?.rotated(by: deterministicGeometricAngle) ?? processedImage

            if processedImage == nil {
                processedImage = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Error processing image")?
                    .cgImage(forProposedRect: nil, context: nil, hints: nil)
            }

            let mockWindowProvider = MockPreviewWindow(
                windowID: CGWindowID(i + 1),
                frame: CGRect(x: 100 * (i + 1), y: 100, width: 250, height: 180),
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
                    isMinimized: false,
                    isHidden: false,
                    lastAccessedTime: Date()
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
            coordinator.currIndex = 0
        }
        return coordinator
    }
}

struct AppearanceSettingsView: View {
    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.showAppName) var showAppName
    @Default(.appNameStyle) var appNameStyle
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleDisplayCondition) var windowTitleDisplayCondition
    @Default(.windowTitleVisibility) var windowTitleVisibility
    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.windowSwitcherControlPosition) var windowSwitcherControlPosition
    @Default(.dockPreviewControlPosition) var dockPreviewControlPosition
    @Default(.dimInSwitcherUntilSelected) var dimInSwitcherUntilSelected
    @Default(.selectionOpacity) var selectionOpacity
    @Default(.hoverHighlightColor) var hoverHighlightColor
    @Default(.previewMaxColumns) var previewMaxColumns
    @Default(.previewMaxRows) var previewMaxRows
    @Default(.switcherMaxRows) var switcherMaxRows
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.globalPaddingMultiplier) var globalPaddingMultiplier

    @State private var showAdvancedAppearanceSettings: Bool = false
    @State private var selectedPreviewContext: PreviewContext = .dock

    @State private var previousWindowTitlePosition: WindowTitlePosition
    @State private var mockAppNameForPreview: String = "DockDoor (•‿•)"
    @StateObject private var mockWindowSwitcherCoordinator: PreviewStateCoordinator
    @StateObject private var mockDockPreviewCoordinator: PreviewStateCoordinator

    private let advancedAppearanceSettingsSectionID = "advancedAppearanceSettingsSection"

    init() {
        _previousWindowTitlePosition = State(initialValue: Defaults[.windowTitlePosition])

        let initialMockWindows = AppearanceSettingsView.generateMockWindowsForPreview(count: 2)

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
                    StyledGroupBox(label: "Window Preview Size") {
                        VStack(alignment: .leading, spacing: 10) {
                            WindowSizeDropdownView()

                            Text("Choose how large window previews appear when hovering over dock icons. All window images are automatically scaled to fit within this size while maintaining their original proportions.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    StyledGroupBox(label: "General Appearance") {
                        VStack(alignment: .leading, spacing: 10) {
                            sliderSetting(title: "Spacing Scale",
                                          value: $globalPaddingMultiplier,
                                          range: 0.5 ... 2.0,
                                          step: 0.1,
                                          unit: "×",
                                          formatter: {
                                              let f = NumberFormatter()
                                              f.minimumFractionDigits = 1
                                              f.maximumFractionDigits = 1
                                              return f
                                          }())

                            VStack(alignment: .leading) {
                                Toggle(isOn: $uniformCardRadius) {
                                    Text("Rounded corners")
                                }
                                Text("Round the corners of window preview images for a modern look.")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                    .padding(.leading, 20)
                            }
                        }
                    }

                    VStack {
                        Picker("", selection: $selectedPreviewContext.animation(Animation.smooth)) {
                            ForEach(PreviewContext.allCases) { context in
                                Text(context.displayName).tag(context)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack {
                        let currentCoordinator = selectedPreviewContext == .dock ? mockDockPreviewCoordinator : mockWindowSwitcherCoordinator
                        if !currentCoordinator.windows.isEmpty {
                            MockWindowPreviewContainer(
                                appName: mockAppNameForPreview,
                                coordinator: currentCoordinator,
                                isWindowSwitcher: selectedPreviewContext == .windowSwitcher
                            )
                            .allowsHitTesting(false)
                        } else {
                            Text("Loading preview...")
                                .frame(minHeight: 150, maxHeight: 250)
                        }
                    }

                    StyledGroupBox(label: selectedPreviewContext == .dock ? "Dock Preview Settings" : "Window Switcher Settings") {
                        VStack(alignment: .leading, spacing: 10) {
                            if selectedPreviewContext == .dock {
                                dockPreviewSettings
                            } else {
                                windowSwitcherPreviewSettings
                            }
                        }
                    }

                    advancedSettingsToggle(proxy: proxy)

                    if showAdvancedAppearanceSettings {
                        advancedAppearanceSettingsSection
                            .id(advancedAppearanceSettingsSectionID)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dockPreviewSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $showAppName) {
                Text("Show App Name in Dock Previews")
            }

            Picker(String(localized: "App Name Style"), selection: $appNameStyle) {
                ForEach(AppNameStyle.allCases, id: \.self) { style in
                    Text(style.localizedName)
                        .tag(style)
                }
            }
            .disabled(!showAppName)

            Divider().padding(.vertical, 2)
            Text("Dock Preview Toolbar").font(.headline).padding(.bottom, -2)

            Picker("Position Dock Preview Controls", selection: $dockPreviewControlPosition) {
                ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Toggle(isOn: $showWindowTitle) {
                Text("Show Window Title")
            }

            Toggle(isOn: Binding(
                get: { !showAppIconOnly },
                set: { showAppIconOnly = !$0 }
            )) {
                Text("Show App Name")
            }

            if showWindowTitle {
                Picker("Show Window Title in", selection: $windowTitleDisplayCondition) {
                    ForEach(WindowTitleDisplayCondition.allCases, id: \.self) { condition in
                        Text(condition.localizedName)
                            .tag(condition)
                    }
                }

                Picker("Window Title Visibility", selection: $windowTitleVisibility) {
                    ForEach(WindowTitleVisibility.allCases, id: \.self) { visibility in
                        Text(visibility.localizedName)
                            .tag(visibility)
                    }
                }
            }

            Divider().padding(.vertical, 2)
            Text("Traffic Light Buttons in Previews").font(.headline).padding(.bottom, -2)
            TrafficLightButtonsSettingsView()

            Divider().padding(.vertical, 2)
            Text("Preview Layout (Dock)").font(.headline).padding(.bottom, -2)

            VStack(alignment: .leading, spacing: 4) {
                let previewMaxRowsBinding = Binding<Double>(
                    get: { Double(previewMaxRows) },
                    set: { previewMaxRows = Int($0) }
                )
                sliderSetting(title: "Max Rows (Bottom Dock)",
                              value: previewMaxRowsBinding,
                              range: 1.0 ... 8.0,
                              step: 1.0,
                              unit: "",
                              formatter: {
                                  let f = NumberFormatter()
                                  f.minimumFractionDigits = 0
                                  f.maximumFractionDigits = 0
                                  return f
                              }())

                let previewMaxColumnsBinding = Binding<Double>(
                    get: { Double(previewMaxColumns) },
                    set: { previewMaxColumns = Int($0) }
                )
                sliderSetting(title: "Max Columns (Left/Right Dock)",
                              value: previewMaxColumnsBinding,
                              range: 1.0 ... 8.0,
                              step: 1.0,
                              unit: "",
                              formatter: {
                                  let f = NumberFormatter()
                                  f.minimumFractionDigits = 0
                                  f.maximumFractionDigits = 0
                                  return f
                              }())

                Text(String(localized: "Controls how many rows/columns of windows are shown in dock previews. Only the relevant setting applies based on dock position."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var windowSwitcherPreviewSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Position Window Controls", selection: $windowSwitcherControlPosition) {
                ForEach(WindowSwitcherControlPosition.allCases, id: \.self) { position in
                    Text(position.localizedName)
                        .tag(position)
                }
            }
            .pickerStyle(MenuPickerStyle())

            VStack(alignment: .leading) {
                Toggle(isOn: $dimInSwitcherUntilSelected) {
                    Text("Dim Unselected Windows")
                }
                Text("When enabled, dims all windows except those currently under selected.")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }

            Divider().padding(.vertical, 2)
            Text("Preview Layout (Switcher)").font(.headline).padding(.bottom, -2)
            VStack(alignment: .leading, spacing: 4) {
                let switcherMaxRowsBinding = Binding<Double>(
                    get: { Double(switcherMaxRows) },
                    set: { switcherMaxRows = Int($0) }
                )
                sliderSetting(title: "Max Rows",
                              value: switcherMaxRowsBinding,
                              range: 1.0 ... 8.0,
                              step: 1.0,
                              unit: "",
                              formatter: {
                                  let f = NumberFormatter()
                                  f.minimumFractionDigits = 0
                                  f.maximumFractionDigits = 0
                                  return f
                              }())

                Text(String(localized: "Controls how many rows of windows are shown in the window switcher. Windows are distributed across rows automatically."))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

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

    @ViewBuilder
    private var advancedAppearanceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            StyledGroupBox(label: "Window Background") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("All window previews show a gray background. When hovered, the background changes to the accent color or custom color below.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        ColorPicker("Custom Hover Highlight Color", selection: Binding(
                            get: { hoverHighlightColor ?? Color(nsColor: .controlAccentColor) },
                            set: { hoverHighlightColor = $0 }
                        ))
                        Button(action: {
                            Defaults.reset(.hoverHighlightColor)
                        }) {
                            Text("Reset")
                        }
                        .buttonStyle(AccentButtonStyle(small: true))
                    }

                    sliderSetting(title: "Background Opacity",
                                  value: $selectionOpacity,
                                  range: 0 ... 1,
                                  step: 0.05,
                                  unit: "",
                                  formatter: NumberFormatter.percentFormatter)
                }
            }

            StyledGroupBox(label: "Color Customization") {
                GradientColorPaletteSettingsView()
            }
        }
        .padding(.top, 10)
    }

    struct WindowSizeDropdownView: View {
        @Default(.previewPixelSize) var previewPixelSize

        private let pixelSizeOptions: [CGFloat] = [100, 120, 150, 180, 200, 220, 250, 280, 300, 350, 400]

        private var visualScaleFactor: CGFloat {
            let maxWidth: CGFloat = 450
            let maxHeight: CGFloat = 120
            return min(maxWidth / 450, maxHeight / 300) * 0.9
        }

        private var visualScreenSize: CGSize {
            CGSize(width: 180 * visualScaleFactor, height: 120 * visualScaleFactor)
        }

        private var visualPreviewSize: CGSize {
            let baseWidth: CGFloat = 80
            let scaleFactor = previewPixelSize / 200.0 // Normalize around 200px
            let width = baseWidth * scaleFactor
            let height = width / (16.0 / 9.0) // 16:9 aspect ratio
            return CGSize(width: width, height: height)
        }

        private func getSizeDescription(_ value: CGFloat) -> String {
            let intValue = Int(value)
            switch intValue {
            case 100 ... 150: return "\(intValue)px (Small)"
            case 151 ... 220: return "\(intValue)px (Medium)"
            case 221 ... 300: return "\(intValue)px (Large)"
            default: return "\(intValue)px (Extra Large)"
            }
        }

        var body: some View {
            HStack(alignment: .top, spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        .frame(width: visualScreenSize.width, height: visualScreenSize.height)
                        .overlay(
                            Text("Dock Preview Area")
                                .font(.caption2)
                                .padding(.top, 2),
                            alignment: .top
                        )

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: visualPreviewSize.width, height: visualPreviewSize.height)
                        .overlay(
                            Text("16:9")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.white)
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Window Preview Size")
                        .font(.subheadline.weight(.medium))
                        .padding(.bottom, 2)

                    Menu {
                        ForEach(pixelSizeOptions, id: \.self) { value in
                            Button(action: { previewPixelSize = value }) {
                                HStack {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.accentColor.opacity(0.3))
                                        .frame(width: max(8, value / 10), height: 12)

                                    Text(getSizeDescription(value))
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if previewPixelSize == value {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                            .font(.caption.weight(.semibold))
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(getSizeDescription(previewPixelSize))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .onChange(of: previewPixelSize) { _ in
                SharedPreviewWindowCoordinator.activeInstance?.windowSize = getWindowSize()
            }
        }
    }
}

// MARK: - Mock Window Preview Container

struct MockWindowPreviewContainer: View {
    let appName: String
    let coordinator: PreviewStateCoordinator
    let isWindowSwitcher: Bool

    @Default(.uniformCardRadius) var uniformCardRadius
    @Default(.showAppName) var showAppName
    @Default(.appNameStyle) var appNameStyle
    @Default(.showWindowTitle) var showWindowTitle
    @Default(.windowTitleDisplayCondition) var windowTitleDisplayCondition
    @Default(.windowTitleVisibility) var windowTitleVisibility
    @Default(.windowTitlePosition) var windowTitlePosition
    @Default(.showAppIconOnly) var showAppIconOnly

    var body: some View {
        BaseHoverContainer(bestGuessMonitor: NSScreen.main!, mockPreviewActive: true) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(coordinator.windows.enumerated()), id: \.offset) { index, window in
                        WindowPreview(
                            windowInfo: window,
                            onTap: nil,
                            index: index,
                            dockPosition: .bottom,
                            maxWindowDimension: coordinator.overallMaxPreviewDimension,
                            bestGuessMonitor: NSScreen.main!,
                            uniformCardRadius: uniformCardRadius,
                            handleWindowAction: { _ in },
                            currIndex: coordinator.currIndex,
                            windowSwitcherActive: isWindowSwitcher,
                            dimensions: coordinator.windowDimensionsMap[index] ?? WindowPreviewHoverContainer.WindowDimensions(size: CGSize(width: 200, height: 150), maxDimensions: CGSize(width: 200, height: 150)),
                            showAppIconOnly: showAppIconOnly,
                            mockPreviewActive: true
                        )
                        .id("\(appName)-\(index)")
                    }
                }
                .frame(alignment: .topLeading)
                .globalPadding(20)
            }
            .overlay(alignment: .topLeading) {
                if !isWindowSwitcher, showAppName {
                    mockHoverTitle
                        .padding(.top, appNameStyle == .default ? 35 : 10)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.top, (!isWindowSwitcher && appNameStyle == .popover && showAppName) ? 30 : 0)
    }

    @ViewBuilder
    private var mockHoverTitle: some View {
        HStack(alignment: .center) {
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }

            if !showAppIconOnly {
                Text(appName)
                    .foregroundStyle(Color.primary)
            }
        }
    }
}
