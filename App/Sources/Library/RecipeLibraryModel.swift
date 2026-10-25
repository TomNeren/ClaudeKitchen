import KitchenCore
import Observation

/// Owns the bundled recipes and the search query of the library screen.
@MainActor @Observable
final class RecipeLibraryModel {
    private(set) var recipes: [Recipe]
    private(set) var loadFailed: Bool
    var query = ""

    init(recipes: [Recipe]? = nil) {
        if let recipes {
            self.recipes = recipes
            loadFailed = false
        } else {
            do {
                self.recipes = try RecipeLibrary.bundled()
                loadFailed = false
            } catch {
                self.recipes = []
                loadFailed = true
            }
        }
    }

    var visibleRecipes: [Recipe] {
        RecipeSearch.filter(recipes, query: query)
    }

    func recipe(_ id: RecipeID) -> Recipe? {
        recipes.first { $0.id == id }
    }
}
