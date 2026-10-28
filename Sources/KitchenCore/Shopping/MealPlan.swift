import Foundation

/// The recipes the cook means to make, with servings and optionally the day. Adding a planned recipe again adds its
/// servings.
///
/// Entries are keyed by the recipe as it is in the library: an own recipe saved from "Mit Claude verbessern" has its
/// own entry, even though it names its original in `variantOf`. Health variants are not library recipes; they are
/// the entry's `goal`.
public struct MealPlan: Sendable, Hashable, Codable {
    public struct Entry: Sendable, Hashable, Codable, Identifiable {
        public var recipe: RecipeID
        public var servings: Int
        /// The health goal whose variant is cooked, nil for the original.
        public var goal: RewriteGoalID?
        /// The day the cook means to make it, nil when not decided. Missing in files from before days existed.
        public var day: PlanDay?

        public var id: RecipeID { recipe }

        public init(recipe: RecipeID, servings: Int, goal: RewriteGoalID? = nil, day: PlanDay? = nil) {
            self.recipe = recipe
            self.servings = servings
            self.goal = goal
            self.day = day
        }
    }

    /// The recipes planned for one day, for the morning reminder.
    public struct Reminder: Sendable, Hashable {
        public var day: PlanDay
        public var entries: [Entry]
    }

    public private(set) var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = []
        for entry in entries {
            add(entry.recipe, servings: entry.servings, goal: entry.goal)
            if let day = entry.day {
                setDay(day, for: entry.recipe)
            }
        }
    }

    /// Dated entries first, by day, then the undated ones in the order they were planned.
    public var scheduled: [Entry] {
        let dated = entries.compactMap { entry in entry.day.map { (day: $0, entry: entry) } }
        // A stable sort: recipes on the same day keep the order they were planned in.
        let byDay = dated.enumerated().sorted { ($0.element.day, $0.offset) < ($1.element.day, $1.offset) }
        return byDay.map(\.element.entry) + entries.filter { $0.day == nil }
    }

    /// Nil removes the day; an unplanned recipe is ignored.
    public mutating func setDay(_ day: PlanDay?, for recipe: RecipeID) {
        guard let index = entries.firstIndex(where: { $0.recipe == recipe }) else { return }
        entries[index].day = day
    }

    /// Puts `entry` back exactly as it was, day included, replacing the recipe's current entry. For undo.
    public mutating func restore(_ entry: Entry) {
        if let index = entries.firstIndex(where: { $0.recipe == entry.recipe }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }

    /// One reminder per day from `today` on that has recipes planned, earliest first. Days already past get none.
    public func reminders(from today: PlanDay) -> [Reminder] {
        var reminders: [Reminder] = []
        for entry in scheduled {
            guard let day = entry.day, day >= today else { continue }
            if reminders.last?.day == day {
                reminders[reminders.count - 1].entries.append(entry)
            } else {
                reminders.append(Reminder(day: day, entries: [entry]))
            }
        }
        return reminders
    }

    /// Servings below 1 count as 1. A recipe already planned keeps one entry: its servings add up, the latest goal
    /// wins and its day stays.
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

    /// Takes what `recipe` used out of the pantry and the cooked servings off the plan entry of `planned`, the
    /// library recipe the cook started from. `recipe` can be its health variant, whose `variantOf` names it too; an
    /// own recipe saved from Claude also has `variantOf` (its original) and must not take servings off that.
    public mutating func cooked(_ recipe: Recipe, as planned: RecipeID, servings: Int, catalog: FoodCatalog) {
        pantry = pantry.cooking(recipe, servings: servings, catalog: catalog)
        plan.cooked(planned, servings: servings)
    }

    /// Drops ticks of items that are no longer on `list`, so they do not come back ticked later.
    public mutating func keepChecks(on list: ShoppingList) {
        checked.formIntersection(list.items.map(\.id))
    }
}
