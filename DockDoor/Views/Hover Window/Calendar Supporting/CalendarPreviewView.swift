import Defaults
import EventKit
import SwiftUI

struct CalendarPreviewView: View {
    let onTap: (() -> Void)?
    let mouseLocation: CGPoint?
    let bestGuessMonitor: NSScreen
    let dockPosition: DockPosition

    @StateObject private var viewModel = CalendarViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Today")
                        .font(.system(size: 13, weight: .semibold))
                    Text(Date().formatted(.dateTime.month().day()))
                        .font(.system(size: 24, weight: .medium))
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

            // Events list
            Group {
                switch viewModel.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .requestingAccess:
                    Text("Requesting Calendar Access...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .noAccess:
                    VStack(spacing: 8) {
                        Text("Calendar Access Required")
                            .font(.system(size: 13, weight: .medium))
                        Text("DockDoor needs access to display your calendar events")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Request Access") {
                            viewModel.requestAccess()
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)

                        Button("Open Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendar")!)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case let .error(message):
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case let .loaded(events):
                    if events.isEmpty {
                        Text("No events today")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(events, id: \.eventIdentifier) { event in
                                    EventRow(event: event)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .frame(width: 280)
        .background(Material.ultraThick)
        .cornerRadius(16)
        .padding(.all, 24)
        .frame(maxWidth: bestGuessMonitor.visibleFrame.width, maxHeight: bestGuessMonitor.visibleFrame.height)
        .overlay {
            if let mouseLocation {
                WindowDismissalContainer(appName: "Calendar", mouseLocation: mouseLocation,
                                         bestGuessMonitor: bestGuessMonitor, dockPosition: dockPosition)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct EventRow: View {
    let event: EKEvent

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(event.startDate, style: .time)
                    if !Calendar.current.isDate(event.startDate, equalTo: event.endDate, toGranularity: .minute) {
                        Text("–")
                        Text(event.endDate, style: .time)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            Spacer()

            Circle()
                .fill(Color(event.calendar.cgColor))
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        }
    }
}

class CalendarViewModel: ObservableObject {
    enum ViewState {
        case loading
        case requestingAccess
        case noAccess
        case error(String)
        case loaded([EKEvent])
    }

    @Published private(set) var state: ViewState = .loading
    private var eventStore = EKEventStore()

    init() {
        Task { @MainActor in
            await checkAuthorizationStatus()
        }
    }

    @MainActor
    private func checkAuthorizationStatus() async {
        let status = EKEventStore.authorizationStatus(for: .event)
        print("Current authorization status: \(status.rawValue)")

        switch status {
        case .authorized:
            print("Calendar access is authorized")
            await fetchTodayEvents()
        case .notDetermined:
            print("Calendar access not determined")
            state = .noAccess // Start in noAccess state to show the request button
        case .restricted, .denied:
            print("Calendar access denied or restricted")
            state = .noAccess
        @unknown default:
            print("Unknown calendar authorization status")
            state = .error("Unknown authorization status")
        }
    }

    @MainActor
    func requestAccess() {
        state = .requestingAccess
        print("Requesting calendar access...")

        Task { [weak self] in
            guard let self else { return }

            // Ensure we're on the main thread for UI operations
            await MainActor.run {
                // Create a new event store instance
                self.eventStore = EKEventStore()

                print("Initializing permission request...")

                // Request permission
                self.eventStore.requestAccess(to: .event) { [weak self] granted, error in
                    print("Permission request callback - granted: \(granted), error: \(String(describing: error))")

                    Task { @MainActor [weak self] in
                        guard let self else { return }

                        if granted {
                            print("Access granted, fetching events")
                            await fetchTodayEvents()
                        } else {
                            if let error {
                                print("Error requesting access: \(error)")
                                state = .error(error.localizedDescription)
                            } else {
                                print("Access denied without error")
                                state = .noAccess
                            }
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func fetchTodayEvents() async {
        do {
            let calendar = Calendar.current
            let now = Date()

            guard let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now),
                  let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)
            else {
                state = .error("Date error")
                return
            }

            let predicate = eventStore.predicateForEvents(
                withStart: startOfDay,
                end: endOfDay,
                calendars: nil
            )

            let events = eventStore.events(matching: predicate)
                .sorted { $0.startDate < $1.startDate }

            print("Successfully fetched \(events.count) events")
            state = .loaded(events)
        } catch {
            print("Error fetching events: \(error)")
            state = .error("Unable to fetch events")
        }
    }
}
