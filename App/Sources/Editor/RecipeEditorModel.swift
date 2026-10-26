import Foundation
import KitchenCore
import Observation

/// One recipe being edited. Changes stay in `recipe` until the cook saves; every rule comes from KitchenCore.
@MainActor @Observable
final class RecipeEditorModel {
    var recipe: Recipe {
        didSet { revalidate() }
    }
    let profile: DeviceProfile
    private let catalog: FoodCatalog?
    /// True for a recipe that is not stored yet: a new one or a copy of a bundled one.
    let isNew: Bool
    private let original: Recipe
    /// `recipe` with foods assigned by name, computed once per change for the checks and the "Erkannt als" rows.
    private var matched: Recipe
    /// Every catalog food, for the picker; the catalog does not change while editing.
    let foods: [Food]

    init(
        recipe: Recipe, isNew: Bool, profile: DeviceProfile = .omniCook, catalog: FoodCatalog? = FoodCatalog.shared
    ) {
        self.recipe = recipe
        self.original = recipe
        self.isNew = isNew
        self.profile = profile
        self.catalog = catalog
        self.matched = recipe
        self.foods = (catalog?.foods ?? []).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        revalidate()
    }

    var hasChanges: Bool { isNew || recipe != original }

    /// Checked once per change, not on every read: the form reads them per row and on every keystroke.
    private(set) var problems: [EditingProblem] = []
    private(set) var issues: [ValidationIssue] = []
    private var issuesByStep: [StepID: [ValidationIssue]] = [:]

    var canSave: Bool {
        problems.isEmpty && !issues.contains { $0.severity == .error }
    }

    func issues(for step: StepID) -> [ValidationIssue] {
        issuesByStep[step] ?? []
    }

    private func revalidate() {
        problems = recipe.editingProblems
        matched = withFoods(recipe)
        issues = profile.validate(matched)
        let stepIssues = issues.compactMap { issue in issue.stepID.map { ($0, issue) } }
        issuesByStep = Dictionary(grouping: stepIssues, by: \.0).mapValues { $0.map(\.1) }
    }

    func stepIndex(_ id: StepID) -> Int? {
        recipe.steps.firstIndex { $0.id == id }
    }

    func ingredientIndex(_ id: IngredientID) -> Int? {
        recipe.ingredients.firstIndex { $0.id == id }
    }

    /// The food an ingredient counts as: chosen by hand, or matched by its name as it will be saved.
    func food(for id: IngredientID) -> Food? {
        guard let food = matched.ingredient(id)?.food else { return nil }
        return catalog?.food(food)
    }

    func isFoodChosenByHand(_ id: IngredientID) -> Bool {
        recipe.ingredient(id)?.foodChosenByHand ?? false
    }

    /// Picks the food by hand; nil means the ingredient counts as no food.
    func chooseFood(_ food: FoodID?, for id: IngredientID) {
        guard let index = ingredientIndex(id) else { return }
        recipe.ingredients[index].food = food
        recipe.ingredients[index].foodChosenByHand = true
    }

    /// Back to matching by name. When the name matches nothing, the current food stays, so a boil check is not lost.
    func matchFoodByName(for id: IngredientID) {
        guard let index = ingredientIndex(id) else { return }
        let name = recipe.ingredients[index].name
        recipe.ingredients[index].foodChosenByHand = false
        if let match = catalog?.food(named: name) {
            recipe.ingredients[index].food = match
        }
    }

    /// False for a food with a safety rule such as raw beans: dropping it would also drop the warning.
    func canDropFood(for id: IngredientID) -> Bool {
        food(for: id)?.mustBoil == nil
    }

    func addIngredient() -> IngredientID {
        recipe.addIngredient(named: "", amount: .measured(100, .gram))
    }

    /// Adds typed or pasted lines like "200 g Rote Linsen" as ingredients, in order, as one change.
    func addIngredients(_ lines: [IngredientLine]) {
        var recipe = recipe
        for line in lines {
            recipe.addIngredient(named: line.name, amount: line.amount, note: line.note)
        }
        self.recipe = recipe
    }

    func addStep() -> StepID {
        recipe.addStep()
    }

    /// `recipe` with catalog foods for new and renamed ingredients, so the checks see what will be saved.
    private func withFoods(_ recipe: Recipe) -> Recipe {
        catalog.map { recipe.assigningFoods(from: $0, comparedTo: original) } ?? recipe
    }

    /// The recipe as it will be saved: names trimmed, foods assigned by name.
    var cleanedRecipe: Recipe {
        var recipe = recipe
        recipe.name = recipe.name.trimmingCharacters(in: .whitespacesAndNewlines)
        recipe.tag = recipe.tag.trimmingCharacters(in: .whitespacesAndNewlines)
        for index in recipe.ingredients.indices {
            recipe.ingredients[index].name = recipe.ingredients[index].name.trimmingCharacters(in: .whitespaces)
        }
        return withFoods(recipe)
    }
}
