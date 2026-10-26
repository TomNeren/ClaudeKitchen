import KitchenCore
import Observation

/// Servings, the chosen health goal and derived values for one recipe screen. All rules come from KitchenCore.
@MainActor @Observable
final class RecipeDetailModel {
    /// The recipe as written; the variant, if a goal is chosen, is derived from it.
    let recipe: Recipe
    let profile: DeviceProfile
    let advisor: HealthAdvisor?
    /// Range of the servings stepper for the shown recipe: the app default, capped so the pot stays below the fill
    /// mark. A goal can change it, because a variant can hold more or less volume.
    private(set) var servingsRange: ClosedRange<Int>
    private(set) var servings: Int
    /// Nil shows the original recipe.
    var goal: RewriteGoalID? {
        didSet { applyGoal() }
    }
    /// With the setting on, every health goal keeps the vegetarian swaps.
    private let vegetarian: Bool
    private(set) var variant: RecipeVariant?

    /// With `vegetarianByDefault`, a recipe the vegetarian goal changes or offers something for opens in that
    /// variant; the original stays one choice away in the goal menu.
    init(
        recipe: Recipe, profile: DeviceProfile = .omniCook, advisor: HealthAdvisor? = HealthGoals.advisor,
        vegetarianByDefault: Bool = HealthGoals.vegetarianByDefault
    ) {
        self.recipe = recipe
        self.profile = profile
        self.advisor = advisor
        self.vegetarian = vegetarianByDefault
        servingsRange = profile.servingsRange(for: recipe)
        servings = recipe.baseServings
        // `affects` is cheap, so recipes without meat or fish skip the rewrite entirely.
        if vegetarianByDefault, recipe.variantOf == nil, advisor?.affects(recipe, goal: RewriteGoal.vegetarian) == true
        {
            goal = RewriteGoal.vegetarian
            // didSet does not run inside init.
            applyGoal()
        }
    }

    private func applyGoal() {
        variant = goal.flatMap { goal in
            advisor?.variant(
                of: recipe, for: goal, combinedWith: HealthGoals.standing(under: goal, vegetarian: vegetarian))
        }
        servingsRange = profile.servingsRange(for: displayed)
        servings = min(max(servings, servingsRange.lowerBound), servingsRange.upperBound)
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
