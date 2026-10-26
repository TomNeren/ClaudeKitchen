import Foundation

/// The recipes the cook means to make, with servings. Adding a planned recipe again adds its servings.
public struct MealPlan: Sendable, Hashable, Codable {
    public struct Entry: Sendable, Hashable, Codable, Identifiable {
        public var recipe: RecipeID
        public var servings: Int
        /// The health goal whose variant is cooked, nil for the original.
        public var goal: RewriteGoalID?

        public var id: RecipeID { recipe }

        public init(recipe: RecipeID, servings: Int, goal: RewriteGoalID? = nil) {
            self.recipe = recipe
            self.servings = servings
            self.goal = goal
        }
    }

    public private(set) var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = []
        for entry in entries {
            add(entry.recipe, servings: entry.servings, goal: entry.goal)
        }
    }

    /// Servings below 1 count as 1. A recipe already planned keeps one entry: its servings add up and the latest
    /// goal wins.
    public mutating func add(_ recipe: RecipeID, servings: Int, goal: RewriteGoalID? = nil) {
        if let index = entries.firstIndex(where: { $0.recipe == recipe }) {
            entries[index].servings += max(1, servings)
            entries[index].goal = goal
        } else {
            entries.append(Entry(recipe: recipe, servings: max(1, servings), goal: goal))
        }
    }

    /// Takes cooked servings off a planned recipe and drops it when none are left; an unplanned recipe is ignored.
    public mutating func cooked(_ recipe: RecipeID, servings: Int) {
        guard let index = entries.firstIndex(where: { $0.recipe == recipe }) else { return }
        entries[index].servings -= max(1, servings)
        if entries[index].servings <= 0 {
            entries.remove(at: index)
        }
    }

    /// Servings below 1 count as 1; an unplanned recipe is ignored.
    public mutating func setServings(_ servings: Int, for recipe: RecipeID) {
        guard let index = entries.firstIndex(where: { $0.recipe == recipe }) else { return }
        entries[index].servings = max(1, servings)
    }

    public mutating func remove(_ recipe: RecipeID) {
        entries.removeAll { $0.recipe == recipe }
    }

    /// The planned recipes found in `recipes`, in plan order; entries whose recipe is gone are skipped. `variant`
    /// turns an entry's recipe into the one for its goal (the app passes the health advisor); nil keeps the original.
    public func plans(
        in recipes: [Recipe], variant: (Recipe, RewriteGoalID) -> Recipe? = { _, _ in nil }
    ) -> [(recipe: Recipe, servings: Int)] {
        let byID = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return entries.compactMap { entry in
            guard let recipe = byID[entry.recipe] else { return nil }
            return (entry.goal.flatMap { variant(recipe, $0) } ?? recipe, entry.servings)
        }
    }
}

/// Everything the shopping screens keep between launches: the plan, the pantry and what is ticked off.
public struct ShoppingState: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var plan: MealPlan
    public var pantry: Pantry
    /// `ShoppingList.Item.id`s ticked off in the shop.
    public var checked: Set<String>

    public init(plan: MealPlan = MealPlan(), pantry: Pantry = Pantry(), checked: Set<String> = []) {
        schemaVersion = Self.currentSchemaVersion
        self.plan = plan
        self.pantry = pantry
        self.checked = checked
    }

    /// The list for the plan, with recipes looked up in `recipes` and turned into their goal's variant by `variant`.
    public func list(
        recipes: [Recipe], catalog: FoodCatalog, variant: (Recipe, RewriteGoalID) -> Recipe? = { _, _ in nil }
    ) -> ShoppingList {
        ShoppingList(plans: plan.plans(in: recipes, variant: variant), pantry: pantry, catalog: catalog)
    }

    /// Books the ticked-off items of `list` into the pantry and clears the ticks. The plan stays: the recipes are
    /// still to be cooked, and the next list no longer asks for what is now at home.
    public mutating func buyChecked(from list: ShoppingList) {
        pantry = pantry.buying(list.filtered(to: checked))
        checked = []
    }

    /// Takes what `recipe` used out of the pantry and the cooked servings off the plan.
    public mutating func cooked(_ recipe: Recipe, servings: Int, catalog: FoodCatalog) {
        pantry = pantry.cooking(recipe, servings: servings, catalog: catalog)
        plan.cooked(recipe.variantOf ?? recipe.id, servings: servings)
    }

    /// Drops ticks of items that are no longer on `list`, so they do not come back ticked later.
    public mutating func keepChecks(on list: ShoppingList) {
        checked.formIntersection(list.items.map(\.id))
    }
}
