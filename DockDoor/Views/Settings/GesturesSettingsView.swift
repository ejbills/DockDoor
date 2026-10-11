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
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                gestureGroup(title: "On a Window's Title Bar", gestures: WindowGestureArea.titleBar.gestures)
                gestureGroup(title: "On a Dock Icon", gestures: WindowGestureArea.dock.gestures)
                gestureGroup(title: "On the Menu Bar", gestures: WindowGestureArea.menuBar.gestures)
                optionsSection
                dockSpaceSection
                SettingsNote(
                    icon: "info.circle",
                    text: "While Window Gestures is on, two-finger scrolling on title bars, running Dock icons and the menu bar is used for these gestures."
                )
                moreGesturesSection
            }
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
        SettingsGroup {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $enableWindowGestures) {
                        Text("Window Gestures")
                            .font(.title3.weight(.semibold))
                    }
                    .toggleStyle(.switch)
                    .settingsSearchTarget("windowGestures.enable")

                    Text("Snap, minimize and close windows with two fingers on your trackpad. Swipe or pinch on a window's title bar, a Dock icon or the menu bar.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

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
        VStack(alignment: .leading, spacing: 6) {
            if !requirements.pinchEnabled {
                Label("Pinches need \"Zoom in or out\" turned on in Trackpad settings.", systemImage: "exclamationmark.triangle.fill")
            }
            if !requirements.smartZoomEnabled {
                Label("Double-taps need \"Smart zoom\" turned on in Trackpad settings.", systemImage: "exclamationmark.triangle.fill")
            }
            Button("Open Trackpad Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
        }
        .font(.caption)
        .foregroundStyle(.orange)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.orange.opacity(0.1)))
    }

    // MARK: - Gestures

    private func gestureGroup(title: LocalizedStringKey, gestures: [WindowGesture]) -> some View {
        SettingsGroup(header: title) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(gestures.enumerated()), id: \.element) { index, gesture in
                    if index > 0 {
                        Divider()
                    }
                    WindowGestureRow(gesture: gesture, isOn: binding(for: gesture))
                        .settingsSearchTarget("windowGestures.\(gesture.rawValue)")
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

    // MARK: - Options

    private var optionsSection: some View {
        SettingsGroup(header: "Options") {
            VStack(alignment: .leading, spacing: 12) {
                let sensitivityBinding = Binding<Double>(
                    get: { Double(sensitivity) },
                    set: { sensitivity = CGFloat($0) }
                )
                sliderSetting(
                    title: "Sensitivity",
                    value: sensitivityBinding,
                    range: Double(WindowGestureRecognizer.Configuration.sensitivityRange.lowerBound) ... Double(WindowGestureRecognizer.Configuration.sensitivityRange.upperBound),
                    step: 0.1,
                    unit: "",
                    formatter: NumberFormatter.percentFormatter
                )
                .settingsSearchTarget("windowGestures.sensitivity")

                Text("Turn this up if gestures need too much finger movement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Show where the window will land", isOn: $livePreview)
                    .settingsSearchTarget("windowGestures.livePreview")

                Toggle("Haptic feedback", isOn: $haptics)
                    .settingsSearchTarget("windowGestures.haptics")
            }
        }
    }

    // MARK: - More Gestures

    private var moreGesturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("More Gestures")
                    .font(.title3.weight(.semibold))
                Text("Scrolling on Dock icons and title bars, swipes on previews, and a trackpad swipe for the window switcher.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)

            if enableWindowGestures {
                SettingsNote(
                    icon: "info.circle",
                    text: "Window Gestures handles scrolling on Dock icons and title bars, so these two are off while it's on."
                )
            }
            Group {
                DockScrollGestureSection()
                TitleBarScrollGestureSection()
            }
            .disabled(enableWindowGestures)
            .opacity(enableWindowGestures ? 0.45 : 1)

            DockPreviewGesturesSection()
            GestureSettingsSection()
            TrackpadSwitcherSwipeSection()
        }
    }

    // MARK: - Custom Dock Space

    private var dockSpaceSection: some View {
        SettingsGroup(header: "Space for a Custom Dock") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Using a dock other than the macOS Dock? Keep a strip of the screen free so snapped windows don't cover it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("Dock edge", selection: $reservationEdge) {
                    ForEach(ScreenReservationEdge.allCases) { edge in
                        Text(edge.localizedName).tag(edge)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .settingsSearchTarget("windowGestures.dockSpace")

                if reservationEdge != .none {
                    let thicknessBinding = Binding<Double>(
                        get: { Double(reservationThickness) },
                        set: { reservationThickness = CGFloat($0) }
                    )
                    sliderSetting(
                        title: reservationEdge == .left || reservationEdge == .right ? "Dock Width" : "Dock Height",
                        value: thicknessBinding,
                        range: 10 ... 300,
                        step: 2,
                        unit: "px",
                        formatter: {
                            let formatter = NumberFormatter()
                            formatter.maximumFractionDigits = 0
                            return formatter
                        }()
                    )
                }

                if !reports.isEmpty {
                    Divider()
                    Text("Reported by Apps")
                        .font(.caption.weight(.semibold))
                    ForEach(reports, id: \.source) { report in
                        ReportedReservationRow(report: report)
                    }
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
                .controlSize(.small)
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
