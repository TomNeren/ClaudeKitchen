import Foundation
import KitchenCore
import Observation

/// Owns the bundled recipes, the cook's own recipes and the search query of the library screen.
@MainActor @Observable
final class RecipeLibraryModel {
    private(set) var bundled: [Recipe] {
        didSet { cuisines = RecipeSearch.cuisines(in: recipes) }
    }
    private(set) var own: [Recipe] = [] {
        didSet { cuisines = RecipeSearch.cuisines(in: recipes) }
    }
    /// Cuisines that have at least one recipe, for the filter menu. Kept up to date when recipes load.
    private(set) var cuisines: [Cuisine] = []
    private(set) var loadFailed: Bool
    var query = ""
    /// Nil shows every cuisine.
    var cuisine: Cuisine?

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
        cuisines = RecipeSearch.cuisines(in: recipes)
    }

    /// Own recipes first, they are the ones the cook added on purpose.
    var recipes: [Recipe] { own + bundled }

    var visibleRecipes: [Recipe] {
        RecipeSearch.filter(recipes, query: query, cuisine: cuisine, cuisineName: \.displayName)
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

    /// Stores an own recipe, new or changed, and reloads the list. Returns false when writing failed.
    @discardableResult
    func save(_ recipe: Recipe) async -> Bool {
        do {
            try await store.save(recipe)
            await loadOwn()
            return true
        } catch {
            return false
        }
    }

    /// What editing `id` means: an own recipe is edited in place, a bundled one as an own copy.
    func editorRequest(for id: RecipeID) -> EditorRequest? {
        guard let recipe = recipe(id) else { return nil }
        if isOwn(id) {
            return EditorRequest(recipe: recipe, isNew: false)
        }
        return EditorRequest(recipe: recipe.copy(id: Self.newID(), name: recipe.name), isNew: true, copiedFrom: id)
    }

    func newRecipeRequest() -> EditorRequest {
        EditorRequest(recipe: .blank(id: Self.newID()), isNew: true)
    }

    static func newID() -> RecipeID {
        RecipeID("eigen-\(UUID().uuidString.prefix(8).lowercased())")
    }

    func delete(_ id: RecipeID) async {
        try? await store.delete(id)
        await loadOwn()
    }
}

/// A recipe handed to the editor.
struct EditorRequest: Identifiable {
    var recipe: Recipe
    var isNew: Bool
    /// The bundled recipe this is a copy of, so the screen can switch to the copy after saving.
    var copiedFrom: RecipeID?

    var id: RecipeID { recipe.id }
}
