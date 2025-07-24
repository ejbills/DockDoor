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
    @Default(.dimInSwitcherUntilSelected) var dimInSwitcherUntilSelected
    @Default(.selectionOpacity) var selectionOpacity
    @Default(.selectionColor) var selectionColor
    @Default(.previewMaxColumns) var previewMaxColumns
    @Default(.previewMaxRows) var previewMaxRows
    @Default(.switcherMaxRows) var switcherMaxRows
    @Default(.showAppIconOnly) var showAppIconOnly
    @Default(.useAccentColorForSelection) var useAccentColorForSelection
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

        let initialMockWindows = AppearanceSettingsView.generateMockWindowsForPreview(count: 1)

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
                    StyledGroupBox(label: "General Appearance") {
                        VStack(alignment: .leading, spacing: 10) {
                            WindowSizeSliderView()

                            sliderSetting(title: "Global Padding Scale",
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
                                    Text("Rounded image corners")
                                }
                                Text("When enabled, all preview images will be cropped to a rounded rectangle.")
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
                            WindowPreviewHoverContainer(
                                appName: mockAppNameForPreview,
                                onWindowTap: nil,
                                dockPosition: .bottom,
                                mouseLocation: .zero,
                                bestGuessMonitor: NSScreen.main!,
                                windowSwitcherCoordinator: currentCoordinator,
                                mockPreviewActive: true,
                                updateAvailable: false
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
            Text("Window Titles in Previews").font(.headline).padding(.bottom, -2)
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

                Picker("Window Title Position", selection: $windowTitlePosition) {
                    ForEach(WindowTitlePosition.allCases, id: \.self) { position in
                        Text(position.localizedName)
                            .tag(position)
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
            StyledGroupBox(label: "Selection Highlight") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $useAccentColorForSelection) {
                        Text("Use System Accent Color for Highlight")
                    }
                    HStack {
                        ColorPicker("Window Selection Background Color", selection: Binding(
                            get: { selectionColor ?? .secondary },
                            set: { selectionColor = $0 }
                        ))
                        .disabled(useAccentColorForSelection)
                        Button(action: {
                            Defaults.reset(.selectionColor)
                        }) {
                            Text("Reset")
                        }
                        .buttonStyle(AccentButtonStyle(small: true))
                    }
                    .disabled(useAccentColorForSelection)

                    sliderSetting(title: "Window Selection Background Opacity",
                                  value: $selectionOpacity,
                                  range: 0 ... 1,
                                  step: 0.05,
                                  unit: "",
                                  formatter: NumberFormatter.percentFormatter)
                        .disabled(useAccentColorForSelection)
                }
            }

            StyledGroupBox(label: "Color Customization") {
                GradientColorPaletteSettingsView()
            }
        }
        .padding(.top, 10)
    }

    struct WindowSizeSliderView: View {
        @Default(.sizingMultiplier) var sizingMultiplier

        private var visualScaleFactor: CGFloat {
            let maxWidth: CGFloat = 450
            let maxHeight: CGFloat = 120
            let widthScale = maxWidth / optimisticScreenSizeWidth
            let heightScale = maxHeight / optimisticScreenSizeHeight
            return min(widthScale, heightScale) * 0.9
        }

        private var scaledPreviewSize: CGSize {
            CGSize(
                width: optimisticScreenSizeWidth / sizingMultiplier,
                height: optimisticScreenSizeHeight / sizingMultiplier
            )
        }

        private var visualScreenSize: CGSize {
            CGSize(
                width: optimisticScreenSizeWidth * visualScaleFactor,
                height: optimisticScreenSizeHeight * visualScaleFactor
            )
        }

        private var visualPreviewSize: CGSize {
            CGSize(
                width: scaledPreviewSize.width * visualScaleFactor,
                height: scaledPreviewSize.height * visualScaleFactor
            )
        }

        private func getSizeDescription(_ value: Int) -> String {
            switch value {
            case 2: String(localized: "Large (1/2)")
            case 3, 4: String(localized: "Medium (1/\(value))")
            case 5, 6: String(localized: "Small (1/\(value))")
            default: String(localized: "Tiny (1/\(value))")
            }
        }

        var body: some View {
            HStack(alignment: .top, spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        .frame(width: visualScreenSize.width, height: visualScreenSize.height)
                        .overlay(
                            Text(String(localized: "Screen"))
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 4),
                            alignment: .top
                        )

                    Rectangle()
                        .fill(Color.blue.opacity(0.35))
                        .frame(width: visualPreviewSize.width, height: visualPreviewSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Preview Size"))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                    Menu {
                        ForEach(2 ... 10, id: \.self) { value in
                            Button(action: { sizingMultiplier = Double(value) }) {
                                HStack {
                                    Rectangle()
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 60 / Double(value), height: 16)
                                        .cornerRadius(2)

                                    Text(getSizeDescription(value))
                                        .frame(width: 100, alignment: .leading)

                                    if sizingMultiplier == Double(value) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(getSizeDescription(Int(sizingMultiplier)))
                                .frame(width: 100, alignment: .leading)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
            .onChange(of: sizingMultiplier) { _ in
                SharedPreviewWindowCoordinator.activeInstance?.windowSize = getWindowSize()
            }
        }
    }
}
