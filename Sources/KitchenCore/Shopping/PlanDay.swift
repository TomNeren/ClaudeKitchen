import Foundation

/// A calendar day without a time or a time zone: a recipe planned for Wednesday stays on Wednesday wherever the
/// phone is.
public struct PlanDay: Sendable, Hashable, Codable, Comparable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar`.
    public init(_ date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 1, month: components.month ?? 1, day: components.day ?? 1)
    }

    /// Midnight at the start of the day in `calendar`.
    public func date(in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// The day `count` days later (earlier for negative counts), across month and year ends.
    public func adding(days count: Int, calendar: Calendar) -> PlanDay {
        guard let start = date(in: calendar), let moved = calendar.date(byAdding: .day, value: count, to: start)
        else { return self }
        return PlanDay(moved, calendar: calendar)
    }

    /// `count` days from this one, starting with it: the choices for a plan entry.
    public func following(_ count: Int, calendar: Calendar) -> [PlanDay] {
        (0..<max(0, count)).map { adding(days: $0, calendar: calendar) }
    }

    public static func < (lhs: PlanDay, rhs: PlanDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// "2026-10-28", stable for identifiers.
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
