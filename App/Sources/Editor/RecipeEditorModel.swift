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

    init(
        recipe: Recipe, isNew: Bool, profile: DeviceProfile = .omniCook, catalog: FoodCatalog? = FoodCatalog.shared
    ) {
        self.recipe = recipe
        self.original = recipe
        self.isNew = isNew
        self.profile = profile
        self.catalog = catalog
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
        issues = profile.validate(withFoods(recipe))
        let stepIssues = issues.compactMap { issue in issue.stepID.map { ($0, issue) } }
        issuesByStep = Dictionary(grouping: stepIssues, by: \.0).mapValues { $0.map(\.1) }
    }

    func stepIndex(_ id: StepID) -> Int? {
        recipe.steps.firstIndex { $0.id == id }
    }

    func ingredientIndex(_ id: IngredientID) -> Int? {
        recipe.ingredients.firstIndex { $0.id == id }
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
