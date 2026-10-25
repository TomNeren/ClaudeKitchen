import KitchenCore
import Observation

/// Servings and derived values for one recipe screen. All rules come from KitchenCore.
@MainActor @Observable
final class RecipeDetailModel {
    let recipe: Recipe
    let profile: DeviceProfile
    /// Range of the servings stepper: the app default, capped so the pot stays below the fill mark.
    let servingsRange: ClosedRange<Int>
    private(set) var servings: Int

    init(recipe: Recipe, profile: DeviceProfile = .omniCook) {
        self.recipe = recipe
        self.profile = profile
        servingsRange = profile.servingsRange(for: recipe)
        servings = recipe.baseServings
    }

    var canDecrease: Bool { servings > servingsRange.lowerBound }
    var canIncrease: Bool { servings < servingsRange.upperBound }

    func decrease() {
        if canDecrease { servings -= 1 }
    }

    func increase() {
        if canIncrease { servings += 1 }
    }

    var ingredients: [(ingredient: Ingredient, text: String)] {
        recipe.ingredients.map { ingredient in
            (ingredient, AmountFormatter.string(for: ingredient.amount(from: recipe.baseServings, to: servings)))
        }
    }

    /// Validation warnings for the current servings, for example an exceeded fill mark.
    var warnings: [ValidationIssue] {
        profile.validate(recipe, servings: servings).filter { $0.severity == .warning }
    }
}
