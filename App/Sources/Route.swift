import KitchenCore

/// Every screen the navigation stack can push.
enum Route: Hashable {
    case recipe(RecipeID)
    case cooking(RecipeID, servings: Int)
}
