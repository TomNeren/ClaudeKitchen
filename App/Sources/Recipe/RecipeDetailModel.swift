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
        didSet {
            variant = goal.flatMap { advisor?.variant(of: recipe, for: $0) }
            servingsRange = profile.servingsRange(for: displayed)
            servings = min(max(servings, servingsRange.lowerBound), servingsRange.upperBound)
        }
    }
    private(set) var variant: RecipeVariant?

    /// With `vegetarianByDefault`, a recipe the vegetarian goal swaps meat in opens in that variant; the original
    /// stays one choice away in the goal menu.
    init(
        recipe: Recipe, profile: DeviceProfile = .omniCook, advisor: HealthAdvisor? = HealthGoals.advisor,
        vegetarianByDefault: Bool = HealthGoals.vegetarianByDefault
    ) {
        self.recipe = recipe
        self.profile = profile
        self.advisor = advisor
        servingsRange = profile.servingsRange(for: recipe)
        servings = recipe.baseServings
        if vegetarianByDefault, recipe.variantOf == nil,
            let vegetarian = advisor?.variant(of: recipe, for: RewriteGoal.vegetarian),
            vegetarian.changes.contains(where: { !$0.change.isOffer })
        {
            // didSet does not run inside init, so the derived values are set here too.
            goal = RewriteGoal.vegetarian
            variant = vegetarian
            servingsRange = profile.servingsRange(for: vegetarian.recipe)
            servings = min(max(servings, servingsRange.lowerBound), servingsRange.upperBound)
        }
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
