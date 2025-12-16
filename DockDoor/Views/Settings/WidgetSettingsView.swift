import Defaults
import EventKit
import SwiftUI

private struct CalendarItem: Identifiable {
    let id: String
    let title: String
    let color: CGColor
    let accountName: String

    var calendarIdentifier: String { id }
}

struct WidgetSettingsView: View {
    @Default(.showSpecialAppControls) var showSpecialAppControls
    @Default(.useEmbeddedMediaControls) var useEmbeddedMediaControls
    @Default(.showBigControlsWhenNoValidWindows) var showBigControlsWhenNoValidWindows
    @Default(.enablePinning) var enablePinning
    @Default(.filteredCalendarIdentifiers) var filteredCalendarIdentifiers

    @State private var availableCalendars: [CalendarItem] = []
    @State private var isLoadingCalendars = true
    @State private var authorizationStatus: EKAuthorizationStatus = .notDetermined

    private let eventStore = EKEventStore()

    private func loadCalendars() async -> [CalendarItem] {
        await Task.detached(priority: .userInitiated) {
            let eventStore = EKEventStore()

            let calendars = eventStore.calendars(for: .event)
                .map { cal in
                    CalendarItem(
                        id: cal.calendarIdentifier,
                        title: cal.title,
                        color: cal.cgColor,
                        accountName: cal.source.title
                    )
                }
                .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

            return calendars
        }.value
    }

    private func cleanupStaleFilters() {
        let validIdentifiers = Set(availableCalendars.map(\.calendarIdentifier))
        let staleIdentifiers = filteredCalendarIdentifiers.filter { !validIdentifiers.contains($0) }

        if !staleIdentifiers.isEmpty {
            filteredCalendarIdentifiers.removeAll { staleIdentifiers.contains($0) }
        }
    }

    var body: some View {
        BaseSettingsView {
            VStack(alignment: .leading, spacing: 16) {
                StyledGroupBox(label: "General") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $showSpecialAppControls) {
                            Text("Show media/calendar controls on Dock hover")
                        }
                        Text("For supported apps (Music, Spotify, Calendar), show interactive controls instead of window previews when hovering their Dock icons.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)

                        if showSpecialAppControls {
                            Toggle(isOn: $useEmbeddedMediaControls) {
                                Text("Embed controls with window previews (if previews shown)")
                            }
                            .padding(.leading, 20)
                            Text("If enabled, controls integrate with previews when possible.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 40)

                            Toggle(isOn: $showBigControlsWhenNoValidWindows) {
                                Text("Show big controls when no valid windows")
                            }
                            .padding(.leading, 20)
                            .disabled(!useEmbeddedMediaControls)
                            Text(useEmbeddedMediaControls ?
                                "When embedded mode is enabled, show big controls instead of embedded ones if all windows are minimized/hidden or there are no windows." :
                                "This setting only applies when \"Embed controls with window previews\" is enabled above.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 40)
                                .opacity(useEmbeddedMediaControls ? 1.0 : 0.6)

                            Toggle(isOn: $enablePinning) {
                                Text("Enable Pinning")
                            }
                            .padding(.leading, 20)
                            .onChange(of: enablePinning) { isEnabled in
                                if !isEnabled {
                                    SharedPreviewWindowCoordinator.activeInstance?.unpinAll()
                                }
                            }
                            Text("Allow special app controls to be pinned to the screen via right-click menu.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 40)
                        }
                    }
                }

                StyledGroupBox(label: "Calendar") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select which calendars appear in the dock preview when hovering over the Calendar app.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)

                        if authorizationStatus == .denied || authorizationStatus == .restricted {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)

                                Text("Calendar Access Required")
                                    .font(.headline)

                                Text("DockDoor needs access to your calendars to show events. Please enable Calendar access in System Settings > Privacy & Security > Calendars.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)

                                Button("Open System Settings") {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(AccentButtonStyle(color: .accentColor))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    if isLoadingCalendars {
                                        HStack {
                                            Spacer()
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text("Loading calendars...")
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                        .padding()
                                    } else if availableCalendars.isEmpty {
                                        VStack(spacing: 8) {
                                            Text("No calendars found")
                                                .foregroundColor(.secondary)
                                            Text("Make sure you have calendars set up in the Calendar app.")
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                    } else {
                                        ForEach(availableCalendars) { calendar in
                                            HStack(spacing: 8) {
                                                Toggle(isOn: Binding(
                                                    get: {
                                                        !filteredCalendarIdentifiers.contains(calendar.calendarIdentifier)
                                                    },
                                                    set: { isEnabled in
                                                        if isEnabled {
                                                            filteredCalendarIdentifiers.removeAll { $0 == calendar.calendarIdentifier }
                                                        } else {
                                                            if !filteredCalendarIdentifiers.contains(calendar.calendarIdentifier) {
                                                                filteredCalendarIdentifiers.append(calendar.calendarIdentifier)
                                                            }
                                                        }
                                                    }
                                                )) { EmptyView() }

                                                Circle()
                                                    .fill(Color(cgColor: calendar.color))
                                                    .frame(width: 12, height: 12)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(calendar.title)
                                                        .lineLimit(1)

                                                    Text(calendar.accountName)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }

                                                Spacer()
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                                .padding(8)
                            }
                            .frame(height: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            )

                            if !availableCalendars.isEmpty {
                                HStack {
                                    Button("Show All") {
                                        filteredCalendarIdentifiers.removeAll()
                                    }
                                    .buttonStyle(AccentButtonStyle(color: .accentColor))
                                    .disabled(filteredCalendarIdentifiers.isEmpty)

                                    Spacer()

                                    DangerButton(action: {
                                        for calendar in availableCalendars {
                                            if !filteredCalendarIdentifiers.contains(calendar.calendarIdentifier) {
                                                filteredCalendarIdentifiers.append(calendar.calendarIdentifier)
                                            }
                                        }
                                    }) {
                                        Text("Hide All")
                                    }
                                    .disabled(filteredCalendarIdentifiers.count == availableCalendars.count)
                                }
                            }
                        }
                    }
                }
                .task {
                    authorizationStatus = EKEventStore.authorizationStatus(for: .event)

                    if authorizationStatus == .notDetermined {
                        await withCheckedContinuation { continuation in
                            eventStore.requestAccess(to: .event) { _, _ in
                                continuation.resume()
                            }
                        }
                        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    }

                    if authorizationStatus == .authorized {
                        isLoadingCalendars = true
                        availableCalendars = await loadCalendars()
                        cleanupStaleFilters()
                        isLoadingCalendars = false
                    } else {
                        isLoadingCalendars = false
                    }
                }
            }
        }
    }
}
