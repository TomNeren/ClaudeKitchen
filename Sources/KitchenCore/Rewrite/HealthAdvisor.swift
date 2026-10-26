import Foundation

/// One swap of a variant, with everything the change list shows: what became what, and why.
public struct ChangeDetail: Sendable, Hashable {
    public var change: RecipeChange
    public var rule: SwapRule
    /// Ingredient name in the original recipe, for example "Basmatireis".
    public var originalName: String
    /// Ingredient name in the variant, for example "Vollkornreis".
    public var newName: String
    /// The source the rule cites, nil only for an inconsistent rule set.
    public var source: EvidenceSource?
}

/// A goal's note with its source resolved.
public struct NoteDetail: Sendable, Hashable {
    public var note: GoalNote
    public var source: EvidenceSource?
}

/// A recipe rewritten for one goal, with the numbers to compare it with the original.
public struct RecipeVariant: Sendable, Hashable {
    public var goal: RewriteGoal
    public var rewrite: RecipeRewrite
    public var changes: [ChangeDetail]
    public var notes: [NoteDetail]
    public var nutritionBefore: NutritionFacts
    public var nutritionAfter: NutritionFacts

    public var recipe: Recipe { rewrite.recipe }
}

/// Food catalog and rewrite rules together: the one entry point the app needs for healthy variants.
public struct HealthAdvisor: Sendable {
    public let catalog: FoodCatalog
    public let rules: RewriteRules

    public init(catalog: FoodCatalog, rules: RewriteRules) {
        self.catalog = catalog
        self.rules = rules
    }

    /// The advisor built from the bundled catalog and rules.
    public static func bundled() throws -> HealthAdvisor {
        HealthAdvisor(catalog: try FoodCatalog.bundled(), rules: try RewriteRules.bundled())
    }

    /// Goal IDs in the order of the rules file, for a picker.
    public var goals: [RewriteGoalID] { rules.goals.map(\.id) }

    /// `recipe` rewritten for `goalID`, nil for an unknown goal.
    public func variant(of recipe: Recipe, for goalID: RewriteGoalID) -> RecipeVariant? {
        guard let goal = rules.resolved(goalID) else { return nil }
        let rewrite = recipe.rewritten(for: goal, catalog: catalog)
        let changes = rewrite.changes.compactMap { change -> ChangeDetail? in
            guard let rule = goal.rules.first(where: { $0.id == change.rule }),
                let original = recipe.ingredient(change.ingredient),
                let new = rewrite.recipe.ingredient(change.newIngredient)
            else { return nil }
            return ChangeDetail(
                change: change, rule: rule, originalName: original.name, newName: new.name,
                source: catalog.source(rule.sourceID))
        }
        let notes = goal.notes.map { NoteDetail(note: $0, source: catalog.source($0.sourceID)) }
        return RecipeVariant(
            goal: goal, rewrite: rewrite, changes: changes, notes: notes,
            nutritionBefore: catalog.nutritionPerServing(of: recipe),
            nutritionAfter: catalog.nutritionPerServing(of: rewrite.recipe))
    }
}
