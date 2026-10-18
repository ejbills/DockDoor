import Defaults
import EventKit
import SwiftUI

private struct CalendarItem: Identifiable {
    let id: String
    let title: String
    let color: CGColor
    let accountName: String

    var calendarIdentifier: String {
        id
    }
}

struct WidgetSettingsView: View {
    @Default(.showSpecialAppControls) var showSpecialAppControls
    @Default(.enableMediaWidget) var enableMediaWidget
    @Default(.mediaDetectionMode) var mediaDetectionMode
    @Default(.enableCalendarWidget) var enableCalendarWidget
    @Default(.useEmbeddedMediaControls) var useEmbeddedMediaControls
    @Default(.showBigControlsWhenNoValidWindows) var showBigControlsWhenNoValidWindows
    @Default(.enablePinning) var enablePinning
    @Default(.filteredCalendarIdentifiers) var filteredCalendarIdentifiers
    @Default(.mediaWidgetScrollBehavior) var mediaWidgetScrollBehavior
    @Default(.mediaWidgetScrollDirection) var mediaWidgetScrollDirection
    @Default(.enableFolderWidget) var enableFolderWidget
    @Default(.folderWidgetDefaultSortOrder) var folderWidgetDefaultSortOrder
    @Default(.folderWidgetDefaultSortReversed) var folderWidgetDefaultSortReversed
    @Default(.folderWidgetRememberSortPerFolder) var folderWidgetRememberSortPerFolder
    @Default(.folderWidgetShowHiddenFiles) var folderWidgetShowHiddenFiles

    @State private var availableCalendars: [CalendarItem] = []
    @State private var isLoadingCalendars = true
    @State private var authorizationStatus: EKAuthorizationStatus = .notDetermined

    private var folderWidgetSection: some View {
        SettingsSection("Folder previews") {
            Toggle(isOn: $enableFolderWidget) { Text("Show folder contents on hover") }
                .settingsSearchTarget("widgets.folder")
                .settingsAnnotation("Preview a folder's contents when hovering it in the Dock.")

            if enableFolderWidget {
                Picker("Default sort:", selection: $folderWidgetDefaultSortOrder) {
                    ForEach(FolderWidgetSortOrder.allCases, id: \.self) { order in
                        Text(order.localizedName).tag(order)
                    }
                }
                .settingsSearchTarget("widgets.folderSort")

                Toggle(isOn: $folderWidgetDefaultSortReversed) { Text("Sort descending by default") }
                    .settingsSearchTarget("widgets.folderSortDirection")

                Toggle(isOn: $folderWidgetRememberSortPerFolder) { Text("Remember sorting per folder") }
                    .settingsSearchTarget("widgets.folderRememberSort")

                Toggle(isOn: $folderWidgetShowHiddenFiles) { Text("Show hidden files") }
                    .settingsSearchTarget("widgets.folderHiddenFiles")
            }
        }
    }

    private static let eventStore = EKEventStore()

    private func calendarBinding(for identifier: String) -> Binding<Bool> {
        Binding {
            !filteredCalendarIdentifiers.contains(identifier)
        } set: { isShown in
            if isShown {
                filteredCalendarIdentifiers.removeAll { $0 == identifier }
            } else if !filteredCalendarIdentifiers.contains(identifier) {
                filteredCalendarIdentifiers.append(identifier)
            }
        }
    }

    private func loadCalendars() async -> [CalendarItem] {
        await Task.detached(priority: .userInitiated) {
            let eventStore = EKEventStore()

            return eventStore.calendars(for: .event)
                .map { cal in
                    CalendarItem(
                        id: cal.calendarIdentifier,
                        title: cal.title,
                        color: cal.cgColor,
                        accountName: cal.source.title
                    )
                }
                .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
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
        SettingsFormView {
            SettingsSection("Widget controls") {
                Toggle(isOn: $showSpecialAppControls) {
                    Text("Enable widget controls on Dock hover")
                }
                .settingsSearchTarget("widgets.enable")

                if showSpecialAppControls {
                    Toggle(isOn: $enableMediaWidget) {
                        Text("Media controls")
                    }
                    .settingsSearchTarget("widgets.media")
                    .settingsAnnotation("Show now playing controls when hovering the active media source's Dock icon. Works with any app.")

                    if enableMediaWidget {
                        Picker("Detection mode:", selection: $mediaDetectionMode) {
                            ForEach(MediaDetectionMode.allCases, id: \.self) { mode in
                                Text(mode.localizedName).tag(mode)
                            }
                        }
                        .settingsSearchTarget("widgets.detectionMode")
                        .settingsAnnotation(verbatim: mediaDetectionMode.localizedDescription)
                    }

                    Toggle(isOn: $enableCalendarWidget) {
                        Text("Calendar widget")
                    }
                    .settingsSearchTarget("widgets.calendar")
                    .settingsAnnotation("Show today's events when hovering the Calendar Dock icon.")
                }
            }

            folderWidgetSection

            if showSpecialAppControls {
                SettingsSection("Display") {
                    Toggle(isOn: $useEmbeddedMediaControls) {
                        Text("Show widget controls alongside window previews")
                    }
                    .settingsSearchTarget("widgets.embedded")
                    .settingsAnnotation("Keeps window previews visible when widget controls are shown.")

                    if useEmbeddedMediaControls {
                        Toggle(isOn: $showBigControlsWhenNoValidWindows) {
                            Text("Use full-size controls when all windows are minimized or hidden")
                        }
                        .settingsSearchTarget("widgets.fullSize")
                    }

                    if #available(macOS 15.0, *) {
                        Toggle(isOn: $enablePinning) {
                            Text("Allow pinning controls to screen")
                        }
                        .settingsSearchTarget("widgets.pinning")
                        .onChange(of: enablePinning) { isEnabled in
                            if !isEnabled {
                                SharedPreviewWindowCoordinator.activeInstance?.unpinAll()
                            }
                        }
                        .settingsAnnotation("Right-click a media or calendar widget to pin it.")
                    }
                }

                if enableMediaWidget {
                    SettingsSection("Media widget scroll") {
                        Picker("Behavior:", selection: $mediaWidgetScrollBehavior) {
                            ForEach(MediaWidgetScrollBehavior.allCases, id: \.self) { behavior in
                                Text(behavior.localizedName).tag(behavior)
                            }
                        }
                        .settingsSearchTarget("widgets.scrollBehavior")
                        .settingsAnnotation("Controls what happens when you scroll on the media widget preview.")

                        Picker("Direction:", selection: $mediaWidgetScrollDirection) {
                            ForEach(MediaWidgetScrollDirection.allCases, id: \.self) { direction in
                                Text(direction.localizedName).tag(direction)
                            }
                        }
                        .settingsSearchTarget("widgets.scrollDirection")

                        if mediaWidgetScrollDirection == .horizontal {
                            SettingsCallout(message: Text("Horizontal scrolling may interfere with dock preview gestures."))
                        }
                    }
                }
            }

            if showSpecialAppControls, enableCalendarWidget {
                SettingsSection("Calendar", footer: "Select which calendars appear in the dock preview when hovering over the Calendar app.") {
                    if authorizationStatus == .denied || authorizationStatus == .restricted {
                        SettingsCallout(
                            title: Text("Calendar Access Required"),
                            message: Text("DockDoor needs access to your calendars to show events. Please enable Calendar access in System Settings > Privacy & Security > Calendars."),
                            actionTitle: "Open System Settings"
                        ) {
                            SystemPreferencesHelper.openCalendarPreferences()
                        }
                    } else if isLoadingCalendars {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading calendars...")
                                .foregroundStyle(.secondary)
                        }
                    } else if availableCalendars.isEmpty {
                        SettingsCallout(
                            tone: .info,
                            icon: "calendar",
                            title: Text("No calendars found"),
                            message: Text("Make sure you have calendars set up in the Calendar app.")
                        )
                    } else {
                        ForEach(availableCalendars) { calendar in
                            Toggle(isOn: calendarBinding(for: calendar.calendarIdentifier)) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(cgColor: calendar.color))
                                        .frame(width: 10, height: 10)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(calendar.title)
                                            .lineLimit(1)
                                        Text(calendar.accountName)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }

                        HStack {
                            Button("Show All") {
                                filteredCalendarIdentifiers.removeAll()
                            }
                            .buttonStyle(.settings)
                            .disabled(filteredCalendarIdentifiers.isEmpty)

                            Spacer()

                            Button("Hide All") {
                                filteredCalendarIdentifiers = availableCalendars.map(\.calendarIdentifier)
                            }
                            .buttonStyle(.settings)
                            .disabled(filteredCalendarIdentifiers.count == availableCalendars.count)
                        }
                    }
                }
                .task {
                    authorizationStatus = EKEventStore.authorizationStatus(for: .event)

                    if authorizationStatus == .notDetermined {
                        await withCheckedContinuation { continuation in
                            Self.eventStore.requestAccess(to: .event) { _, _ in
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
