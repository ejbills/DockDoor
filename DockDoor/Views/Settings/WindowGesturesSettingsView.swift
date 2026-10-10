import Defaults
import SwiftUI

struct WindowGesturesSettingsView: View {
    @Default(.enableWindowGestures) var enableWindowGestures
    @Default(.windowGesturesDisabled) var disabledGestures
    @Default(.windowGestureSensitivity) var sensitivity
    @Default(.windowGestureTapAndHold) var tapAndHold
    @Default(.windowGestureHoldDuration) var holdDuration
    @Default(.windowGestureCancelTimeout) var cancelTimeout
    @Default(.windowGestureHaptics) var haptics
    @Default(.windowGestureShowTooltips) var showTooltips
    @Default(.windowGestureTooltipSize) var tooltipSize
    @Default(.windowGestureLivePreview) var livePreview
    @Default(.windowGestureHideCursor) var hideCursor
    @Default(.windowGestureAnywhereModifier) var anywhereModifier
    @Default(.windowGestureGeneralModifier) var generalModifier
    @Default(.windowGestureSecondaryModifier) var secondaryModifier
    @Default(.windowGestureTertiaryModifier) var tertiaryModifier
    @Default(.windowGestureScreenModifier) var screenModifier
    @Default(.windowGestureGridSpacing) var gridSpacing
    @Default(.windowGestureSpacingIncludesEdges) var spacingIncludesEdges
    @Default(.windowGestureStageManagerOffset) var stageManagerOffset
    @Default(.windowGestureDragToUnsnap) var dragToUnsnap
    @Default(.windowGestureResizeAdjacent) var resizeAdjacent
    @Default(.windowGestureActivateAfterSnap) var activateAfterSnap
    @Default(.windowGestureCenterAction) var centerAction
    @Default(.windowGestureMoveCursorWithWindow) var moveCursorWithWindow
    @Default(.windowGestureIgnoredApps) var ignoredApps

    @State private var requirements = TrackpadGestureRequirements.current()
    @State private var showingAddIgnoredApp = false
    @State private var newIgnoredApp = ""

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                if enableWindowGestures {
                    if !requirements.isSatisfied {
                        requirementsSection
                    }
                    ForEach(WindowGestureSection.allCases) { section in
                        gestureSection(section)
                    }
                    modifiersSection
                    feelSection
                    tooltipsSection
                    snappingSection
                    ignoredAppsSection
                    noteSection
                }
            }
        }
        .onAppear { requirements = .current() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            requirements = .current()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        SettingsGroup {
            SettingsIllustratedToggle(isOn: $enableWindowGestures, title: "Window Gestures") {
                Text("Manage windows and apps with two-finger swipes, pinches and taps on title bars, Dock icons and the menu bar. Snap to halves, quarters and thirds, close, quit, minimize, go full screen, and move windows between displays and Spaces.")
            }
            .settingsSearchTarget("windowGestures.enable")
        }
    }

    private var requirementsSection: some View {
        SettingsGroup(header: "Trackpad Settings") {
            VStack(alignment: .leading, spacing: 10) {
                if !requirements.pinchEnabled {
                    Label("Pinch gestures need \"Zoom in or out\" turned on in Trackpad settings.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                if !requirements.smartZoomEnabled {
                    Label("Double-tap gestures need \"Smart zoom\" turned on in Trackpad settings.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Button("Open Trackpad Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .font(.callout)
        }
    }

    // MARK: - Gestures

    private func gestureSection(_ section: WindowGestureSection) -> some View {
        SettingsGroup(header: LocalizedStringKey(section.title)) {
            VStack(alignment: .leading, spacing: 0) {
                Text(section.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 6)

                let gestures = section.gestures
                ForEach(gestures) { gesture in
                    WindowGestureRow(gesture: gesture, isOn: binding(for: gesture))
                        .settingsSearchTarget("windowGestures.\(gesture.rawValue)")
                    if gesture != gestures.last {
                        Divider()
                    }
                }
            }
        }
    }

    private func binding(for gesture: WindowGesture) -> Binding<Bool> {
        Binding(
            get: { !disabledGestures.contains(gesture) },
            set: { isOn in
                if isOn {
                    disabledGestures.remove(gesture)
                } else {
                    disabledGestures.insert(gesture)
                }
            }
        )
    }

    // MARK: - Modifiers

    private var modifiersSection: some View {
        SettingsGroup(header: "Modifier Keys") {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(GestureModifierRole.allCases) { role in
                    HStack(spacing: 12) {
                        SettingsIcon(systemName: role.symbolName)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(role.title)
                                .font(.body)
                                .fontWeight(.medium)
                            Text(role.explanation)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: modifierBinding(for: role)) {
                            ForEach(GestureModifierKey.allCases) { key in
                                Text(key.localizedName).tag(key)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 150)
                    }
                    .padding(.vertical, 6)
                    .settingsSearchTarget("windowGestures.modifier.\(role.rawValue)")

                    if role != GestureModifierRole.allCases.last {
                        Divider()
                    }
                }
            }
        }
    }

    private func modifierBinding(for role: GestureModifierRole) -> Binding<GestureModifierKey> {
        switch role {
        case .anywhere: $anywhereModifier
        case .general: $generalModifier
        case .secondary: $secondaryModifier
        case .tertiary: $tertiaryModifier
        case .screen: $screenModifier
        }
    }

    // MARK: - Feel

    private var feelSection: some View {
        SettingsGroup(header: "Feel") {
            VStack(alignment: .leading, spacing: 12) {
                let sensitivityBinding = Binding<Double>(
                    get: { Double(sensitivity) },
                    set: { sensitivity = CGFloat($0) }
                )
                sliderSetting(
                    title: "Swipe Sensitivity",
                    value: sensitivityBinding,
                    range: Double(WindowGestureRecognizer.Configuration.sensitivityRange.lowerBound) ... Double(WindowGestureRecognizer.Configuration.sensitivityRange.upperBound),
                    step: 0.1,
                    unit: "",
                    formatter: NumberFormatter.percentFormatter
                )
                .settingsSearchTarget("windowGestures.sensitivity")

                Text("Higher values recognize swipes and pinches with less finger travel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Toggle("Tap and hold", isOn: $tapAndHold)
                    .settingsSearchTarget("windowGestures.tapAndHold")

                if tapAndHold {
                    sliderSetting(
                        title: "Hold Duration",
                        value: $holdDuration,
                        range: 0.2 ... 1,
                        step: 0.05,
                        unit: "seconds",
                        formatter: NumberFormatter.twoDecimalFormatter
                    )
                    .settingsSearchTarget("windowGestures.holdDuration")
                }

                Text("Rest two fingers on the trackpad without moving them to unlock extra gestures, like moving windows between Spaces. Shorten the hold if gestures feel slow, or lengthen it if two-finger clicks on Dock icons trigger it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                sliderSetting(
                    title: "Cancel After Resting",
                    value: $cancelTimeout,
                    range: 0.5 ... 5,
                    step: 0.5,
                    unit: "seconds",
                    formatter: NumberFormatter.oneDecimalFormatter
                )
                .settingsSearchTarget("windowGestures.cancelTimeout")

                Text("Cancel a gesture by pressing Esc, or by keeping your fingers still for this long. To repeat a direction, like swiping up twice, pause briefly until you feel a click, then keep going.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Toggle("Haptic feedback", isOn: $haptics)
                    .settingsSearchTarget("windowGestures.haptics")
            }
        }
    }

    // MARK: - Tooltips

    private var tooltipsSection: some View {
        SettingsGroup(header: "Tooltips") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show a tooltip with the action next to the pointer", isOn: $showTooltips)
                    .settingsSearchTarget("windowGestures.tooltips")

                if showTooltips {
                    Picker("Tooltip size", selection: $tooltipSize) {
                        ForEach(WindowGestureTooltipSize.allCases) { size in
                            Text(size.localizedName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .settingsSearchTarget("windowGestures.tooltipSize")
                }

                Toggle("Preview where the window will snap", isOn: $livePreview)
                    .settingsSearchTarget("windowGestures.livePreview")

                Toggle("Hide the pointer while a gesture is in progress", isOn: $hideCursor)
                    .settingsSearchTarget("windowGestures.hideCursor")
            }
        }
    }

    // MARK: - Snapping

    private var snappingSection: some View {
        SettingsGroup(header: "Snapping Options") {
            VStack(alignment: .leading, spacing: 12) {
                let spacingBinding = Binding<Double>(
                    get: { Double(gridSpacing) },
                    set: { gridSpacing = CGFloat($0) }
                )
                sliderSetting(
                    title: "Grid Spacing",
                    value: spacingBinding,
                    range: 0 ... 30,
                    step: 1,
                    unit: "px",
                    formatter: {
                        let formatter = NumberFormatter()
                        formatter.maximumFractionDigits = 0
                        return formatter
                    }()
                )
                .settingsSearchTarget("windowGestures.gridSpacing")

                Toggle("Include screen edges in spacing", isOn: $spacingIncludesEdges)
                    .disabled(gridSpacing == 0)
                    .settingsSearchTarget("windowGestures.spacingEdges")

                Divider()

                let offsetBinding = Binding<Double>(
                    get: { Double(stageManagerOffset) },
                    set: { stageManagerOffset = CGFloat($0) }
                )
                sliderSetting(
                    title: "Stage Manager Space",
                    value: offsetBinding,
                    range: 0 ... 300,
                    step: 10,
                    unit: "px",
                    formatter: {
                        let formatter = NumberFormatter()
                        formatter.maximumFractionDigits = 0
                        return formatter
                    }()
                )
                .settingsSearchTarget("windowGestures.stageManager")

                Text("Leaves room for the recent apps strip when Stage Manager is on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Toggle("Drag a snapped window to restore its size", isOn: $dragToUnsnap)
                    .settingsSearchTarget("windowGestures.dragToUnsnap")

                Toggle("Resize neighboring snapped windows together", isOn: $resizeAdjacent)
                    .settingsSearchTarget("windowGestures.resizeAdjacent")

                Toggle("Bring windows to the front after snapping", isOn: $activateAfterSnap)
                    .settingsSearchTarget("windowGestures.activateAfterSnap")

                Toggle("Move the pointer along when moving a window to another display", isOn: $moveCursorWithWindow)
                    .settingsSearchTarget("windowGestures.moveCursor")

                Picker("Double-tap on a title bar", selection: $centerAction) {
                    ForEach(WindowGestureCenterAction.allCases) { action in
                        Text(action.localizedName).tag(action)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .settingsSearchTarget("windowGestures.centerAction")
            }
        }
    }

    // MARK: - Ignored Apps

    private var ignoredAppsSection: some View {
        SettingsGroup(header: "Ignored Apps") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Window gestures don't respond on these apps' windows, Dock icons or menus.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if ignoredApps.isEmpty {
                    Text("No ignored apps")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(ignoredApps, id: \.self) { app in
                            HStack {
                                Text(app)
                                Spacer()
                                Button {
                                    ignoredApps.removeAll { $0 == app }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                            if app != ignoredApps.last {
                                Divider()
                            }
                        }
                    }
                }

                Button("Add App") {
                    newIgnoredApp = ""
                    showingAddIgnoredApp = true
                }
                .buttonStyle(AccentButtonStyle())
                .settingsSearchTarget("windowGestures.ignoredApps")
            }
        }
        .sheet(isPresented: $showingAddIgnoredApp) {
            AddBlacklistAppSheet(isPresented: $showingAddIgnoredApp, appNameToAdd: $newIgnoredApp) { appName in
                guard !appName.isEmpty,
                      !ignoredApps.contains(where: { $0.caseInsensitiveCompare(appName) == .orderedSame })
                else { return }
                ignoredApps.append(appName)
            }
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        SettingsNote(
            icon: "info.circle",
            text: "While Window Gestures is on, two-finger scrolling on title bars, running Dock icons and the menu bar is used for gestures. It replaces the title bar scroll gesture in Gestures & Keybinds. The three- or four-finger swipe for the window switcher keeps working as before."
        )
    }
}

private struct WindowGestureRow: View {
    let gesture: WindowGesture
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingsIcon(systemName: gesture.symbolName, color: isOn ? .accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(gesture.title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(gesture.instructions)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }
}

struct TrackpadGestureRequirements: Equatable {
    var pinchEnabled: Bool
    var smartZoomEnabled: Bool

    var isSatisfied: Bool { pinchEnabled && smartZoomEnabled }

    static func current() -> TrackpadGestureRequirements {
        TrackpadGestureRequirements(
            pinchEnabled: isEnabled("TrackpadPinch"),
            smartZoomEnabled: isEnabled("TrackpadTwoFingerDoubleTapGesture")
        )
    }

    private static func isEnabled(_ key: String) -> Bool {
        let domains = ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"]
        let values = domains.compactMap { UserDefaults(suiteName: $0)?.object(forKey: key) as? Int }
        guard !values.isEmpty else { return true }
        return values.contains { $0 != 0 }
    }
}
