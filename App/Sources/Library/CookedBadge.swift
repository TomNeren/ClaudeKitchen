import KitchenCore
import SwiftUI

/// Text for "last cooked" and rating, shared by the tile badge, the card line and VoiceOver.
enum CookedText {
    /// "heute", "gestern", "vor 3 Tagen" (up to a week), then a short date.
    static func relative(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days =
            calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
            ).day ?? 0
        switch days {
        case ..<1: return "heute"
        case 1: return "gestern"
        case 2...7: return "vor \(days) Tagen"
        default: return date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "de_DE")))
        }
    }

    static func short(lastCooked: Date?, rating: Int?) -> String? {
        guard let lastCooked else { return nil }
        let when = "Zuletzt gekocht: \(relative(lastCooked))"
        guard let rating else { return when }
        return "\(when) · ★ \(rating)"
    }

    static func spoken(lastCooked: Date?, rating: Int?) -> String? {
        guard let lastCooked else { return nil }
        let when = "Zuletzt gekocht \(relative(lastCooked))"
        guard let rating else { return when }
        return "\(when), bewertet mit \(rating) von 5 Sternen"
    }
}

/// Compact dark capsule on a photo tile. Content overlay, not glass.
struct CookedBadge: View {
    let lastCooked: Date?
    let rating: Int?

    var body: some View {
        if let lastCooked {
            HStack(spacing: 4) {
                Text(CookedText.relative(lastCooked))
                if let rating { Text("★ \(rating)") }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.black.opacity(0.45), in: .capsule)
            .accessibilityHidden(true)
        }
    }
}
