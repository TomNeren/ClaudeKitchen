import Foundation
import KitchenCore

/// German names and texts for the rewrite goals, and the advisor the app shares. Rules live in KitchenCore.
enum HealthGoals {
    /// Nil if the bundled catalog or rules cannot be read; the recipe screen then offers no variants.
    static let advisor: HealthAdvisor? = try? HealthAdvisor.bundled()

    /// Settings key: recipes with meat open in their vegetarian variant. On unless switched off.
    static let vegetarianByDefaultKey = "vegetarianByDefault"

    static var vegetarianByDefault: Bool {
        UserDefaults.standard.object(forKey: vegetarianByDefaultKey) as? Bool ?? true
    }

    /// How much of an ingredient a partial swap replaces, for the change list: "zur Hälfte" or "zu 30 %".
    static func shareText(_ share: Double) -> String {
        share == 0.5 ? "zur Hälfte" : "zu \((share * 100).formatted(.number.precision(.fractionLength(0)))) %"
    }

    static func name(_ id: RewriteGoalID) -> String {
        switch id {
        case RewriteGoal.vegetarian: "Vegetarisch"
        case RewriteGoal.balanced: "Ausgewogen"
        case RewriteGoal.bloodPressure: "Blutdruck"
        case RewriteGoal.weightLoss: "Abnehmen"
        case RewriteGoal.lowCarb: "Low Carb"
        default: id.rawValue
        }
    }

    static func text(for skipped: SkippedSwap, in recipe: Recipe, profile: DeviceProfile) -> String {
        let name = recipe.ingredient(skipped.ingredient)?.name ?? skipped.ingredient.rawValue
        switch skipped.reason {
        case .amountToTaste:
            return "\(name) bleibt: Bei „nach Geschmack“ lässt sich nichts aufteilen."
        case .exceedsMaxDuration:
            let minutes = profile.maxDuration.components.seconds / 60
            return "\(name) bleibt: Die längere Garzeit passt nicht in die \(minutes) Minuten des Geräts."
        }
    }
}
