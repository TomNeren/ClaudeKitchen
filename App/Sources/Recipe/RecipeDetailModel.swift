import KitchenCore
import Observation

/// Servings, the chosen health goal and derived values for one recipe screen. All rules come from KitchenCore.
@MainActor @Observable
final class RecipeDetailModel {
    /// The recipe as written; the variant, if a goal is chosen, is derived from it.
    let recipe: Recipe
    let profile: DeviceProfile
    let advisor: HealthAdvisor?
    /// Range of the servings stepper: the app default, capped so the pot stays below the fill mark.
    let servingsRange: ClosedRange<Int>
    private(set) var servings: Int
    /// Nil shows the original recipe.
    var goal: RewriteGoalID? {
        didSet { variant = goal.flatMap { advisor?.variant(of: recipe, for: $0) } }
    }
    private(set) var variant: RecipeVariant?

    init(recipe: Recipe, profile: DeviceProfile = .omniCook, advisor: HealthAdvisor? = HealthGoals.advisor) {
        self.recipe = recipe
        self.profile = profile
        self.advisor = advisor
        servingsRange = profile.servingsRange(for: recipe)
        servings = recipe.baseServings
    }

    /// The recipe the screen shows and cooks: the variant for the chosen goal, else the original.
    var displayed: Recipe { variant?.recipe ?? recipe }

    var goals: [RewriteGoalID] { advisor?.goals ?? [] }

    var canDecrease: Bool { servings > servingsRange.lowerBound }
    var canIncrease: Bool { servings < servingsRange.upperBound }

    func decrease() {
        if canDecrease { servings -= 1 }
    }

    func increase() {
        if canIncrease { servings += 1 }
    }

    var ingredients: [(ingredient: Ingredient, text: String)] {
        let recipe = displayed
        return recipe.ingredients.map { ingredient in
            (ingredient, AmountFormatter.string(for: ingredient.amount(from: recipe.baseServings, to: servings)))
        }
    }

    /// Validation warnings for the current servings, for example an exceeded fill mark.
    var warnings: [ValidationIssue] {
        profile.validate(displayed, servings: servings).filter { $0.severity == .warning }
    }
}
