import Foundation
import KitchenCore
import Observation

/// The plan, the shopping list and the pantry for all screens. Every change is saved right away.
@MainActor @Observable
final class ShoppingModel {
    private(set) var state = ShoppingState() {
        didSet { refresh() }
    }
    /// Recomputed only when the state or the recipes change, not on every read.
    private(set) var list = ShoppingList(items: [])
    /// The state before the last pantry booking (cooking or buying), for one step of undo.
    private(set) var undoState: ShoppingState?
    private(set) var undoLabel: String?

    private var recipes: [Recipe] = []
    private let store: ShoppingStore
    let catalog: FoodCatalog?

    init(store: ShoppingStore = .shared, catalog: FoodCatalog? = FoodCatalog.shared) {
        self.store = store
        self.catalog = catalog
    }

    func load() async {
        state = await store.load()
    }

    /// The library's recipes, own and bundled, so plan entries resolve.
    func update(recipes: [Recipe]) {
        self.recipes = recipes
        refresh()
    }

    var planned: [PlannedRecipe] {
        state.plan.plans(in: recipes).map { PlannedRecipe(recipe: $0.recipe, servings: $0.servings) }
    }

    func isPlanned(_ id: RecipeID) -> Bool {
        state.plan.entries.contains { $0.recipe == id }
    }

    func add(_ recipe: Recipe, servings: Int) {
        change { $0.plan.add(recipe.variantOf ?? recipe.id, servings: servings) }
    }

    func setServings(_ servings: Int, for id: RecipeID) {
        change { $0.plan.setServings(servings, for: id) }
    }

    func remove(_ id: RecipeID) {
        change { $0.plan.remove(id) }
    }

    func isChecked(_ item: ShoppingList.Item) -> Bool {
        state.checked.contains(item.id)
    }

    func toggle(_ item: ShoppingList.Item) {
        change {
            if $0.checked.contains(item.id) {
                $0.checked.remove(item.id)
            } else {
                $0.checked.insert(item.id)
            }
        }
    }

    var hasChecked: Bool {
        list.items.contains { state.checked.contains($0.id) }
    }

    func buyChecked() {
        let list = list
        booking("Einkauf eingebucht") { $0.buyChecked(from: list) }
    }

    /// Called when the cook finishes a recipe in the cooking mode.
    func cooked(_ recipe: Recipe, servings: Int) {
        guard let catalog else { return }
        booking("\(recipe.name) abgebucht") { $0.cooked(recipe, servings: servings, catalog: catalog) }
    }

    func undo() {
        guard let undoState else { return }
        change { $0 = undoState }
        self.undoState = nil
        undoLabel = nil
    }

    func setPantryItem(_ item: PantryItem?, for food: FoodID) {
        change { $0.pantry[food] = item }
    }

    var pantryItems: [PantryEntry] {
        state.pantry.items.map { PantryEntry(item: $0, name: catalog?.food($0.food)?.name ?? $0.food.rawValue) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// A new pantry entry for `food`: by level for seasonings, else in grams.
    func newPantryItem(for food: Food) -> PantryItem {
        let byLevel = catalog?.tracksLevel(food) ?? false
        return PantryItem(food: food.id, stock: byLevel ? .level(.available) : .grams(0))
    }

    private func booking(_ label: String, _ update: (inout ShoppingState) -> Void) {
        let before = state
        change(update)
        undoState = before
        undoLabel = label
    }

    private func change(_ update: (inout ShoppingState) -> Void) {
        var state = state
        update(&state)
        self.state = state
        let saved = state
        Task { await store.save(saved) }
    }

    private func refresh() {
        guard let catalog else { return }
        list = state.list(recipes: recipes, catalog: catalog)
    }
}

struct PlannedRecipe: Identifiable {
    let recipe: Recipe
    let servings: Int

    var id: RecipeID { recipe.id }
}

struct PantryEntry: Identifiable {
    let item: PantryItem
    let name: String

    var id: FoodID { item.food }
}
