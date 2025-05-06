
import Defaults
import EventKit
import SwiftUI

struct CalendarPreviewView: View {
    let onTap: (() -> Void)?

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
                case .noAccess:
                    VStack(spacing: 8) {
                        Text("Calendar Access Required")
                            .font(.system(size: 13, weight: .medium))
                        Text("Open System Settings to grant access")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
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
        case noAccess
        case error(String)
        case loaded([EKEvent])
    }

    @Published private(set) var state: ViewState = .loading
    private let eventStore = EKEventStore()

    init() {
        Task { @MainActor in
            await requestAccess()
        }
    }

    @MainActor
    private func requestAccess() async {
        do {
            let granted = try await eventStore.requestAccess(to: .event)
            if granted {
                await fetchTodayEvents()
            } else {
                state = .noAccess
            }
        } catch {
            state = .error("Unable to access calendar")
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

            state = .loaded(events)
        } catch {
            state = .error("Unable to fetch events")
        }
    }
}
