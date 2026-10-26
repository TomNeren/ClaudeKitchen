import KitchenCore

/// Every screen the navigation stack can push.
enum Route: Hashable {
    case recipe(RecipeID)
    /// `goal` cooks the recipe's variant for that health goal instead of the original.
    case cooking(RecipeID, servings: Int, goal: RewriteGoalID?)
}
