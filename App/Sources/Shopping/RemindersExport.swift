import EventKit
import Foundation

/// Puts the open shopping items into their own list in Apple Reminders.
///
/// Reminders this app writes carry `marker` as their URL. A new export replaces only those: open ones are removed,
/// a ticked-off one stays and is not written again while its item is still on the list. Reminders the cook adds by
/// hand are never touched. The list is found again by its identifier, so renaming it in Reminders is fine.
actor RemindersExport {
    static let shared = RemindersExport()
    static let listTitle = "Einkauf (Omni Cook)"

    enum Failure: Error {
        case denied
        case noWritableAccount
    }

    private static let marker = URL(string: "omnicook://einkauf")!
    private static let listKey = "remindersShoppingList"

    /// One long-lived store, as EventKit recommends.
    private let store = EKEventStore()

    private struct Existing: Sendable {
        let id: String
        let title: String
        let isCompleted: Bool
    }

    /// Returns how many reminders were written.
    func export(_ lines: [String]) async throws -> Int {
        let wasAuthorized = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
        guard try await store.requestFullAccessToReminders() else { throw Failure.denied }
        if !wasAuthorized {
            // A store created before the first grant does not see the cook's lists until it is reset.
            store.reset()
        }
        let list = try shoppingList()
        let predicate = store.predicateForReminders(in: [list])
        // Only plain values leave the callback; the reminders are looked up again on this side.
        let existing = await withCheckedContinuation { (continuation: CheckedContinuation<[Existing], Never>) in
            // @Sendable: EventKit calls back on its own queue, so the closure must not belong to this actor.
            store.fetchReminders(matching: predicate) { @Sendable reminders in
                let ours = (reminders ?? []).filter { $0.url == Self.marker }
                continuation.resume(
                    returning: ours.map {
                        Existing(id: $0.calendarItemIdentifier, title: $0.title ?? "", isCompleted: $0.isCompleted)
                    })
            }
        }
        let wanted = Set(lines)
        let stillBought = Set(existing.filter { $0.isCompleted && wanted.contains($0.title) }.map(\.title))
        for old in existing where !stillBought.contains(old.title) || !old.isCompleted {
            if let reminder = store.calendarItem(withIdentifier: old.id) as? EKReminder {
                try store.remove(reminder, commit: false)
            }
        }
        let new = lines.filter { !stillBought.contains($0) }
        for line in new {
            let reminder = EKReminder(eventStore: store)
            reminder.title = line
            reminder.url = Self.marker
            reminder.calendar = list
            try store.save(reminder, commit: false)
        }
        try store.commit()
        return new.count
    }

    /// The list from the last export, else one with the title, else a new one in the first account that takes it.
    private func shoppingList() throws -> EKCalendar {
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: Self.listKey), let list = store.calendar(withIdentifier: id),
            list.allowsContentModifications
        {
            return list
        }
        if let list = store.calendars(for: .reminder).first(where: {
            $0.title == Self.listTitle && $0.allowsContentModifications
        }) {
            defaults.set(list.calendarIdentifier, forKey: Self.listKey)
            return list
        }
        let candidates =
            [store.defaultCalendarForNewReminders()?.source].compactMap { $0 }
            + store.sources.filter { $0.sourceType == .calDAV || $0.sourceType == .local }
        for source in candidates {
            let list = EKCalendar(for: .reminder, eventStore: store)
            list.title = Self.listTitle
            list.source = source
            if (try? store.saveCalendar(list, commit: true)) != nil {
                defaults.set(list.calendarIdentifier, forKey: Self.listKey)
                return list
            }
        }
        throw Failure.noWritableAccount
    }
}
