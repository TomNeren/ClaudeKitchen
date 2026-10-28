import Foundation
import KitchenCore
import UserNotifications

/// One local notification per planned day, in the morning, naming what is to be cooked. Early enough to soak beans
/// or take fish out of the freezer.
actor PlanReminders {
    static let shared = PlanReminders()

    struct Day: Sendable {
        let day: PlanDay
        /// "Dal Tadka (3 Portionen)", one per recipe.
        let lines: [String]
    }

    /// Local time of the reminder on the planned day.
    static let hour = 8
    private static let prefix = "plan-day-"

    private let center = UNUserNotificationCenter.current()

    /// Asks once; later calls return what the cook chose. True when reminders may be shown.
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces all plan reminders with `days`. Without permission nothing is scheduled; a day whose morning has
    /// passed is skipped by the system, since the trigger never matches again.
    func schedule(_ days: [Day]) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }
        for day in days {
            let content = UNMutableNotificationContent()
            content.title = day.lines.count == 1 ? "Heute im Kochplan" : "Heute im Kochplan: \(day.lines.count) Rezepte"
            content.body = day.lines.joined(separator: "\n")
            content.sound = .default
            let components = DateComponents(year: day.day.year, month: day.day.month, day: day.day.day, hour: Self.hour)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.prefix + day.day.description, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
