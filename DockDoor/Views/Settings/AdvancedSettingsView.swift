import Defaults
import SwiftUI

struct AdvancedSettingsView: View {
    @Default(.hoverWindowOpenDelay) var hoverWindowOpenDelay
    @Default(.useDelayOnlyForInitialOpen) var useDelayOnlyForInitialOpen
    @Default(.fadeOutDuration) var fadeOutDuration
    @Default(.preventPreviewReentryDuringFadeOut) var preventPreviewReentryDuringFadeOut
    @Default(.inactivityTimeout) var inactivityTimeout
    @Default(.windowProcessingDebounceInterval) var windowProcessingDebounceInterval
    @Default(.anchorDockPreviewPosition) var anchorDockPreviewPosition
    @Default(.preventDockHide) var preventDockHide
    @Default(.cacheValidationInterval) var cacheValidationInterval
    @Default(.raisedWindowLevel) var raisedWindowLevel

    @Default(.windowImageCaptureQuality) var windowImageCaptureQuality
    @Default(.screenCaptureCacheLifespan) var screenCaptureCacheLifespan
    @Default(.windowPreviewImageScale) var windowPreviewImageScale

    @Default(.enableLivePreview) var enableLivePreview
    @Default(.enableLivePreviewForDock) var enableLivePreviewForDock
    @Default(.enableLivePreviewForWindowSwitcher) var enableLivePreviewForWindowSwitcher
    @Default(.dockLivePreviewQuality) var dockLivePreviewQuality
    @Default(.dockLivePreviewFrameRate) var dockLivePreviewFrameRate
    @Default(.windowSwitcherLivePreviewQuality) var windowSwitcherLivePreviewQuality
    @Default(.windowSwitcherLivePreviewFrameRate) var windowSwitcherLivePreviewFrameRate
    @Default(.windowSwitcherLivePreviewScope) var windowSwitcherLivePreviewScope
    @Default(.livePreviewStreamKeepAlive) var livePreviewStreamKeepAlive

    @FocusState private var isKeepAliveFieldFocused: Bool
    @State private var lastKeepAliveDuration: Int = 5

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                performanceTuningSection
                previewQualitySection
                livePreviewSection

                if enableLivePreview {
                    dockLivePreviewSection
                    switcherLivePreviewSection
                    streamManagementSection
                }
            }
        }
        .onAppear {
            if livePreviewStreamKeepAlive > 0 {
                lastKeepAliveDuration = livePreviewStreamKeepAlive
            }
        }
    }

    // MARK: - Performance Tuning

    private var performanceTuningSection: some View {
        SettingsGroup(header: "Performance Tuning") {
            VStack(alignment: .leading, spacing: 10) {
                sliderSetting(title: "Preview Window Open Delay", value: $hoverWindowOpenDelay, range: 0 ... 2, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter)

                Toggle(isOn: $useDelayOnlyForInitialOpen) {
                    Text("Only use delay for initial window opening")
                }
                Text("Switching between dock icons while a preview is already open will show previews instantly.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                sliderSetting(title: "Preview Window Fade Out Duration", value: $fadeOutDuration, range: 0 ... 2, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter)
                sliderSetting(title: "Preview Window Inactivity Timer", value: $inactivityTimeout, range: 0 ... 3, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter)
                sliderSetting(title: "Window Processing Debounce Interval", value: $windowProcessingDebounceInterval, range: 0 ... 3, step: 0.1, unit: "seconds", formatter: NumberFormatter.oneDecimalFormatter, onEditingChanged: { isEditing in
                    if !isEditing {
                        askUserToRestartApplication()
                    }
                })

                sliderSetting(title: "Window Cache Validation Interval", value: $cacheValidationInterval, range: 10 ... 300, step: 10, unit: "seconds", onEditingChanged: { isEditing in
                    if !isEditing {
                        askUserToRestartApplication()
                    }
                })
                Text("How often to validate cached windows in the background. Lower values detect closed windows faster but use more resources.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $anchorDockPreviewPosition) {
                    Text("Anchor preview to initial dock icon position")
                }
                Text("Keeps the preview pinned where the dock icon was when first hovered, preventing it from jumping when the dock auto-hides.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                Toggle(isOn: $preventDockHide) { Text("Prevent dock from hiding during previews") }
                Toggle(isOn: $raisedWindowLevel) { Text("Show preview above app labels").onChange(of: raisedWindowLevel) { _ in askUserToRestartApplication() } }

                Toggle(isOn: $preventPreviewReentryDuringFadeOut) {
                    Text("Prevent preview reappearance during fade-out")
                }
                Text("Moving the mouse back over the preview during fade-out will not reactivate it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    // MARK: - Preview Quality

    private var previewQualitySection: some View {
        SettingsGroup(header: "Preview Quality") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Window Image Capture Quality", selection: $windowImageCaptureQuality) {
                    ForEach(WindowImageCaptureQuality.allCases, id: \.self) { quality in
                        Text(quality.localizedName).tag(quality)
                    }
                }
                .pickerStyle(MenuPickerStyle())

                sliderSetting(title: "Window Image Cache Lifespan", value: $screenCaptureCacheLifespan, range: 0 ... 60, step: 10, unit: "seconds")
                sliderSetting(title: "Window Image Resolution Scale (1=Best)", value: $windowPreviewImageScale, range: 1 ... 4, step: 1, unit: "")
            }
        }
    }

    // MARK: - Live Preview

    private var livePreviewSection: some View {
        SettingsGroup(header: "Live Preview") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $enableLivePreview) { Text("Enable Live Preview (Video)") }
                    .onChange(of: enableLivePreview) { newValue in
                        if !newValue {
                            Task { await LiveCaptureManager.shared.stopAllStreams() }
                        }
                    }
                Text("Window previews show live video instead of static screenshots. Uses ScreenCaptureKit for real-time capture.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)

                if enableLivePreview {
                    Text("Higher quality and frame rate use more CPU/GPU resources. Use lower settings for Window Switcher if you experience lag.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Dock Live Preview

    private var dockLivePreviewSection: some View {
        SettingsGroup(header: "Dock Live Preview") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $enableLivePreviewForDock) { Text("Enable for Dock Preview") }

                if enableLivePreviewForDock {
                    Picker("Quality", selection: $dockLivePreviewQuality) {
                        ForEach(LivePreviewQuality.allCases, id: \.self) { quality in
                            Text(quality.localizedName).tag(quality)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.leading, 20)

                    Picker("Frame Rate", selection: $dockLivePreviewFrameRate) {
                        ForEach(LivePreviewFrameRate.allCases, id: \.self) { fps in
                            Text(fps.localizedName).tag(fps)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.leading, 20)
                }
            }
        }
    }

    // MARK: - Switcher Live Preview

    private var switcherLivePreviewSection: some View {
        SettingsGroup(header: "Switcher Live Preview") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $enableLivePreviewForWindowSwitcher) { Text("Enable for Window Switcher") }

                if enableLivePreviewForWindowSwitcher {
                    Picker("Quality", selection: $windowSwitcherLivePreviewQuality) {
                        ForEach(LivePreviewQuality.allCases, id: \.self) { quality in
                            Text(quality.localizedName).tag(quality)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.leading, 20)

                    Picker("Frame Rate", selection: $windowSwitcherLivePreviewFrameRate) {
                        ForEach(LivePreviewFrameRate.allCases, id: \.self) { fps in
                            Text(fps.localizedName).tag(fps)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.leading, 20)

                    Picker("Scope", selection: $windowSwitcherLivePreviewScope) {
                        ForEach(WindowSwitcherLivePreviewScope.allCases, id: \.self) { scope in
                            Text(scope.localizedName).tag(scope)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.leading, 20)

                    Text(windowSwitcherLivePreviewScope.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
            }
        }
    }

    // MARK: - Stream Management

    private var streamManagementSection: some View {
        SettingsGroup(header: "Stream Management") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Stream Keep-Alive Duration")
                    .onTapGesture { isKeepAliveFieldFocused = false }

                HStack(spacing: 0) {
                    Button(action: {
                        livePreviewStreamKeepAlive = 0
                        isKeepAliveFieldFocused = false
                    }) {
                        Text("Immediately close")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(livePreviewStreamKeepAlive == 0 ? Color.accentColor : Color.secondary.opacity(0.15))
                    .foregroundColor(livePreviewStreamKeepAlive == 0 ? .white : .primary)
                    .contentShape(Rectangle())

                    HStack(spacing: 4) {
                        TextField("", value: Binding(
                            get: { livePreviewStreamKeepAlive > 0 ? livePreviewStreamKeepAlive : lastKeepAliveDuration },
                            set: {
                                let newValue = max(1, $0)
                                lastKeepAliveDuration = newValue

                                if livePreviewStreamKeepAlive > 0 {
                                    livePreviewStreamKeepAlive = newValue
                                }
                            }
                        ), formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 40)
                            .multilineTextAlignment(.center)
                            .focused($isKeepAliveFieldFocused)
                            .onChange(of: isKeepAliveFieldFocused) { focused in
                                if focused, livePreviewStreamKeepAlive <= 0 {
                                    livePreviewStreamKeepAlive = lastKeepAliveDuration
                                }
                            }
                        Text("seconds")
                            .foregroundColor(livePreviewStreamKeepAlive > 0 ? .white : .primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(livePreviewStreamKeepAlive > 0 ? Color.accentColor : Color.secondary.opacity(0.15))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if livePreviewStreamKeepAlive <= 0 {
                            livePreviewStreamKeepAlive = lastKeepAliveDuration
                        }
                    }

                    Button(action: {
                        livePreviewStreamKeepAlive = -1
                        isKeepAliveFieldFocused = false
                    }) {
                        Text("Keep Open")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(livePreviewStreamKeepAlive == -1 ? Color.accentColor : Color.secondary.opacity(0.15))
                    .foregroundColor(livePreviewStreamKeepAlive == -1 ? .white : .primary)
                    .contentShape(Rectangle())
                }
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: livePreviewStreamKeepAlive) { newValue in
                    if newValue == 0 {
                        Task { await LiveCaptureManager.shared.stopAllStreams() }
                    }
                }

                Text("How long to keep video streams active after closing preview. Longer duration means faster reopening but uses more resources.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .onTapGesture { isKeepAliveFieldFocused = false }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(TapGesture().onEnded {
                isKeepAliveFieldFocused = false
            }, including: .gesture)
        }
    }
}
