import EventKit

/// Puts the open shopping items into their own list in Apple Reminders. A new export replaces the list's open
/// reminders, so exporting twice does not double them; ticked-off reminders stay as they are.
enum RemindersExport {
    static let listTitle = "Einkauf (Omni Cook)"

    enum Failure: Error {
        case denied
        case noAccount
    }

    /// Returns how many reminders were written.
    static func export(_ lines: [String]) async throws -> Int {
        let store = EKEventStore()
        guard try await store.requestFullAccessToReminders() else { throw Failure.denied }
        let list = try shoppingList(in: store)
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil, ending: nil, calendars: [list])
        // Only identifiers leave the callback; the reminders themselves are fetched again on this side.
        let open = await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            store.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders?.map(\.calendarItemIdentifier) ?? [])
            }
        }
        for id in open {
            if let reminder = store.calendarItem(withIdentifier: id) as? EKReminder {
                try store.remove(reminder, commit: false)
            }
        }
        for line in lines {
            let reminder = EKReminder(eventStore: store)
            reminder.title = line
            reminder.calendar = list
            try store.save(reminder, commit: false)
        }
        try store.commit()
        return lines.count
    }

    private static func shoppingList(in store: EKEventStore) throws -> EKCalendar {
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == listTitle }) {
            return existing
        }
        guard let source = store.defaultCalendarForNewReminders()?.source else { throw Failure.noAccount }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = listTitle
        list.source = source
        try store.saveCalendar(list, commit: true)
        return list
    }
}
