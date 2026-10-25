import KitchenCore
import Observation

/// Owns the bundled recipes, the cook's own recipes and the search query of the library screen.
@MainActor @Observable
final class RecipeLibraryModel {
    private(set) var bundled: [Recipe]
    private(set) var own: [Recipe] = []
    private(set) var loadFailed: Bool
    var query = ""

    private let store: any RecipeStore

    init(bundled: [Recipe]? = nil, store: any RecipeStore = FileRecipeStore.shared) {
        self.store = store
        if let bundled {
            self.bundled = bundled
            loadFailed = false
        } else {
            do {
                self.bundled = try RecipeLibrary.bundled()
                loadFailed = false
            } catch {
                self.bundled = []
                loadFailed = true
            }
        }
    }

    /// Own recipes first, they are the ones the cook added on purpose.
    var recipes: [Recipe] { own + bundled }

    var visibleRecipes: [Recipe] {
        RecipeSearch.filter(recipes, query: query)
    }

    func recipe(_ id: RecipeID) -> Recipe? {
        recipes.first { $0.id == id }
    }

    func isOwn(_ id: RecipeID) -> Bool {
        own.contains { $0.id == id }
    }

    func loadOwn() async {
        own = (try? await store.load()) ?? []
    }

    func delete(_ id: RecipeID) async {
        try? await store.delete(id)
        await loadOwn()
    }
}
