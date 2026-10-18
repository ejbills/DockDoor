import Defaults
import SwiftUI

struct GesturesSettingsView: View {
    @Default(.enableWindowGestures) var enableWindowGestures
    @Default(.windowGesturesDisabled) var disabledGestures
    @Default(.windowGestureSensitivity) var sensitivity
    @Default(.windowGestureHaptics) var haptics
    @Default(.windowGestureLivePreview) var livePreview
    @Default(.customDockReservationEdge) var reservationEdge
    @Default(.customDockReservationThickness) var reservationThickness

    @State private var requirements = TrackpadGestureRequirements.current()
    @State private var reports = ScreenReservations.shared.reports

    private static let heroGestures: [WindowGesture] = [.snapHalves, .windowClose, .windowMinimize, .appMinimize]

    var body: some View {
        SettingsFormView {
            heroSection

            if enableWindowGestures {
                gestureGroup(title: "On a Window's Title Bar", gestures: WindowGestureArea.titleBar.gestures)
                gestureGroup(title: "On a Dock Icon", gestures: WindowGestureArea.dock.gestures)
                gestureGroup(title: "On the Menu Bar", gestures: WindowGestureArea.menuBar.gestures)
                optionsSection
                dockSpaceSection
                Section {
                    SettingsNote(
                        icon: "info.circle",
                        text: "While Window Gestures is on, two-finger scrolling on title bars, running Dock icons and the menu bar is used for these gestures."
                    )
                }
            } else {
                // Window Gestures owns scrolling on Dock icons and title bars.
                DockScrollGestureSection()
                TitleBarScrollGestureSection()
            }

            DockPreviewGesturesSection()
            GestureSettingsSection()
            MouseActionsSection()
        }
        .onAppear {
            requirements = .current()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            requirements = .current()
        }
        .onReceive(NotificationCenter.default.publisher(for: ScreenReservations.reportsDidChange)) { _ in
            reports = ScreenReservations.shared.reports
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        SettingsSection("Window gestures") {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $enableWindowGestures) {
                        Text("Window Gestures")
                    }
                    .toggleStyle(.switch)
                    .onChange(of: enableWindowGestures) { _ in askUserToRestartApplication() }
                    .settingsSearchTarget("windowGestures.enable")
                    .settingsAnnotation("Snap, minimize and close windows with two fingers on your trackpad. Swipe or pinch on a window's title bar, a Dock icon or the menu bar.")

                    if enableWindowGestures, !requirements.isSatisfied {
                        requirementsBanner
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                GestureDemoCarousel(gestures: Self.heroGestures)
                    .frame(width: 240, height: 170)
            }
        }
    }

    private var requirementsBanner: some View {
        var lines: [Text] = []
        if !requirements.pinchEnabled {
            lines.append(Text("Pinches need \"Zoom in or out\" turned on in Trackpad settings."))
        }
        if !requirements.smartZoomEnabled {
            lines.append(Text("Double-taps need \"Smart zoom\" turned on in Trackpad settings."))
        }
        let message = lines.dropFirst().reduce(lines.first ?? Text(verbatim: "")) { $0 + Text(verbatim: "\n") + $1 }
        return SettingsCallout(tone: .warning, message: message, actionTitle: "Open Trackpad Settings") {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Gestures

    private func gestureGroup(title: LocalizedStringKey, gestures: [WindowGesture]) -> some View {
        SettingsSection(title) {
            ForEach(gestures, id: \.self) { gesture in
                WindowGestureRow(gesture: gesture, isOn: binding(for: gesture))
                    .settingsSearchTarget("windowGestures.\(gesture.rawValue)")
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

    // MARK: - Options

    private var optionsSection: some View {
        SettingsSection("Options") {
            let sensitivityBinding = Binding<Double>(
                get: { Double(sensitivity) },
                set: { sensitivity = CGFloat($0) }
            )
            SettingsSliderRow(
                title: "Sensitivity",
                value: sensitivityBinding,
                range: Double(WindowGestureRecognizer.Configuration.sensitivityRange.lowerBound) ... Double(WindowGestureRecognizer.Configuration.sensitivityRange.upperBound),
                step: 0.1
            )
            .settingsSearchTarget("windowGestures.sensitivity")
            .settingsAnnotation("Turn this up if gestures need too much finger movement.")

            Toggle("Show where the window will land", isOn: $livePreview)
                .settingsSearchTarget("windowGestures.livePreview")

            Toggle("Haptic feedback", isOn: $haptics)
                .settingsSearchTarget("windowGestures.haptics")
        }
    }

    // MARK: - Custom Dock Space

    private var dockSpaceSection: some View {
        SettingsSection("Space for a custom dock", footer: "Using a dock other than the macOS Dock? Keep a strip of the screen free so snapped windows don't cover it.") {
            Picker("Dock edge", selection: $reservationEdge) {
                ForEach(ScreenReservationEdge.allCases) { edge in
                    Text(edge.localizedName).tag(edge)
                }
            }
            .fixedSize()
            .settingsSearchTarget("windowGestures.dockSpace")

            if reservationEdge != .none {
                let thicknessBinding = Binding<Double>(
                    get: { Double(reservationThickness) },
                    set: { reservationThickness = CGFloat($0) }
                )
                SettingsSliderRow(
                    title: reservationEdge == .left || reservationEdge == .right ? "Dock Width" : "Dock Height",
                    value: thicknessBinding,
                    range: 10 ... 300,
                    unit: " px",
                    step: 2,
                    decimals: 0
                )
            }

            if !reports.isEmpty {
                Text("Reported by Apps")
                    .font(.caption.weight(.semibold))
                ForEach(reports, id: \.source) { report in
                    ReportedReservationRow(report: report)
                }
            }
        }
    }
}

private struct WindowGestureRow: View {
    let gesture: WindowGesture
    @Binding var isOn: Bool

    @State private var hovering = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            GestureDemoView(demo: gesture.demo, isPlaying: hovering)
                .frame(width: 112, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .saturation(isOn ? 1 : 0.2)

            VStack(alignment: .leading, spacing: 2) {
                Text(gesture.title)
                    .font(.callout.weight(.semibold))
                Text(gesture.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

private struct ReportedReservationRow: View {
    let report: ScreenReservations.Report

    private var app: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: report.source).first
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon = app?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "dock.rectangle")
                    .foregroundStyle(.secondary)
            }
            Text(app?.localizedName ?? report.source)
                .font(.callout)
            Spacer()
            Text("\(report.reservation.edge.localizedName), \(Int(report.reservation.thickness)) px")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

struct TrackpadGestureRequirements: Equatable {
    var pinchEnabled: Bool
    var smartZoomEnabled: Bool

    var isSatisfied: Bool {
        pinchEnabled && smartZoomEnabled
    }

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
