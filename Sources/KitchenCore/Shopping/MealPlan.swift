import Foundation

/// The recipes the cook means to make, with servings. Adding a planned recipe again adds its servings.
public struct MealPlan: Sendable, Hashable, Codable {
    public struct Entry: Sendable, Hashable, Codable, Identifiable {
        public var recipe: RecipeID
        public var servings: Int

        public var id: RecipeID { recipe }

        public init(recipe: RecipeID, servings: Int) {
            self.recipe = recipe
            self.servings = servings
        }
    }

    public private(set) var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = []
        for entry in entries {
            add(entry.recipe, servings: entry.servings)
        }
    }

    /// Servings below 1 count as 1.
    public mutating func add(_ recipe: RecipeID, servings: Int) {
        if let index = entries.firstIndex(where: { $0.recipe == recipe }) {
            entries[index].servings += max(1, servings)
        } else {
            entries.append(Entry(recipe: recipe, servings: max(1, servings)))
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

    /// The planned recipes found in `recipes`, in plan order; entries whose recipe is gone are skipped.
    public func plans(in recipes: [Recipe]) -> [(recipe: Recipe, servings: Int)] {
        let byID = Dictionary(recipes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return entries.compactMap { entry in byID[entry.recipe].map { ($0, entry.servings) } }
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

    /// The list for the plan, with recipes looked up in `recipes`.
    public func list(recipes: [Recipe], catalog: FoodCatalog) -> ShoppingList {
        ShoppingList(plans: plan.plans(in: recipes), pantry: pantry, catalog: catalog)
    }

    /// Books the ticked-off items of `list` into the pantry and clears the ticks. The plan stays: the recipes are
    /// still to be cooked, and the next list no longer asks for what is now at home.
    public mutating func buyChecked(from list: ShoppingList) {
        pantry = pantry.buying(list.filtered(to: checked))
        checked = []
    }

    /// Takes what `recipe` used out of the pantry and drops it from the plan.
    public mutating func cooked(_ recipe: Recipe, servings: Int, catalog: FoodCatalog) {
        pantry = pantry.cooking(recipe, servings: servings, catalog: catalog)
        plan.remove(recipe.variantOf ?? recipe.id)
    }
}
