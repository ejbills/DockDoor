import EventKit
import Foundation

extension DailyCalendarInfo.Event: Identifiable {
    public var id: String { title + startDate.timeIntervalSince1970.description + (location ?? "") }
}

class DailyCalendarInfo: ObservableObject {
    struct Event {
        let title: String
        let startDate: Date
        let endDate: Date
        let location: String?
        let calendarColor: CGColor?
    }

    private let eventStore = EKEventStore()

    @Published private(set) var events: [Event] = []
    @Published private(set) var eventAuthStatus: EKAuthorizationStatus = .notDetermined

    init() {
        eventAuthStatus = EKEventStore.authorizationStatus(for: .event)
        requestAccessIfNeededAndFetch()
    }

    private func requestAccessIfNeededAndFetch() {
        if eventAuthStatus == .notDetermined {
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.eventAuthStatus = EKEventStore.authorizationStatus(for: .event)
                    self.fetchDataBasedOnCurrentPermissions()
                }
            }
        } else {
            // If status is already determined, fetch data immediately.
            DispatchQueue.main.async {
                self.fetchDataBasedOnCurrentPermissions()
            }
        }
    }

    private func fetchDataBasedOnCurrentPermissions() {
        if eventAuthStatus == .authorized {
            fetchTodaysEvents()
        } else {
            if !events.isEmpty { events = [] }
        }
    }

    func reloadData() {
        DispatchQueue.main.async {
            self.eventAuthStatus = EKEventStore.authorizationStatus(for: .event)
            self.fetchDataBasedOnCurrentPermissions()
        }
    }

    private func fetchTodaysEvents() {
        guard eventAuthStatus == .authorized else {
            if !events.isEmpty { DispatchQueue.main.async { self.events = [] } }
            return
        }

        let calendars = eventStore.calendars(for: .event).filter { cal in
            !cal.title.lowercased().contains("holiday") && cal.type != .birthday
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            if !events.isEmpty { DispatchQueue.main.async { self.events = [] } }
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)

        DispatchQueue.main.async {
            let newEvents = ekEvents.map {
                Event(
                    title: $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    location: $0.location,
                    calendarColor: $0.calendar.cgColor
                )
            }.sorted(by: { $0.startDate < $1.startDate })

            self.events = newEvents
        }
    }
}
