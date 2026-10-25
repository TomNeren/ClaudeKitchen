import Foundation

/// What the editor needs besides `DeviceProfile.validate`: content a recipe cannot be saved without.
public enum EditingProblem: Sendable, Hashable {
    case missingName
    case unnamedIngredient(IngredientID)
    case emptyStep(StepID)
}

extension Recipe {
    /// An empty own recipe with one step to start from.
    public static func blank(id: RecipeID) -> Recipe {
        Recipe(
            id: id, name: "", tag: "", baseServings: 2, totalMinutes: 30, ingredients: [],
            steps: [Step(id: "s1", phase: "", text: "")])
    }

    /// The same recipe under `id`, for example to change a bundled recipe as an own one. Not verified any more.
    public func copy(id: RecipeID, name: String) -> Recipe {
        Recipe(
            id: id, name: name, tag: tag, baseServings: baseServings, totalMinutes: totalMinutes,
            ingredients: ingredients, steps: steps, verified: false)
    }

    /// Adds an ingredient with an id derived from `name` and returns that id.
    @discardableResult
    public mutating func addIngredient(named name: String, amount: Amount = .toTaste) -> IngredientID {
        var taken = Set(ingredients.map(\.id.rawValue))
        let id = IngredientID(Slug.unique(name, fallback: "zutat", taken: &taken))
        ingredients.append(Ingredient(id: id, name: name, amount: amount))
        return id
    }

    /// Removes the ingredient and every reference to it in the steps.
    public mutating func removeIngredient(_ id: IngredientID) {
        ingredients.removeAll { $0.id == id }
        for index in steps.indices {
            steps[index].ingredientIDs.removeAll { $0 == id }
        }
    }

    /// Adds an empty step at the end, or after `index`, and returns its id.
    @discardableResult
    public mutating func addStep(after index: Int? = nil) -> StepID {
        let taken = Set(steps.map(\.id.rawValue))
        var number = steps.count + 1
        while taken.contains("s\(number)") {
            number += 1
        }
        let step = Step(id: StepID("s\(number)"), phase: "", text: "")
        let position = index.map { min($0 + 1, steps.count) } ?? steps.count
        steps.insert(step, at: position)
        return step.id
    }

    public mutating func removeStep(_ id: StepID) {
        steps.removeAll { $0.id == id }
    }

    /// Moves steps like a list does when rows are dragged: `offset` is the position before the move.
    public mutating func moveSteps(fromOffsets source: IndexSet, toOffset offset: Int) {
        steps = Self.moved(steps, fromOffsets: source, toOffset: offset)
    }

    public mutating func moveIngredients(fromOffsets source: IndexSet, toOffset offset: Int) {
        ingredients = Self.moved(ingredients, fromOffsets: source, toOffset: offset)
    }

    /// Content the editor must not save without, in the order the cook sees it.
    public var editingProblems: [EditingProblem] {
        var problems: [EditingProblem] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.append(.missingName)
        }
        for ingredient in ingredients where ingredient.name.trimmingCharacters(in: .whitespaces).isEmpty {
            problems.append(.unnamedIngredient(ingredient.id))
        }
        for step in steps where step.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.append(.emptyStep(step.id))
        }
        return problems
    }

    /// The step's position counted from 1, as the cook sees it.
    public func stepNumber(of id: StepID) -> Int? {
        steps.firstIndex { $0.id == id }.map { $0 + 1 }
    }

    private static func moved<Element>(_ items: [Element], fromOffsets source: IndexSet, toOffset offset: Int)
        -> [Element]
    {
        let moving = source.filter(items.indices.contains).map { items[$0] }
        var rest = items.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let position = min(max(0, offset - source.count(where: { $0 < offset })), rest.count)
        rest.insert(contentsOf: moving, at: position)
        return rest
    }
}

/// Readable ids from names: "Rote Linsen" becomes "rote-linsen", the second one "rote-linsen-2".
enum Slug {
    static func unique(_ text: String, fallback: String, taken: inout Set<String>) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "ß", with: "ss")
        let words = folded.lowercased().split { !($0.isLetter || $0.isNumber) }
        let base = words.isEmpty ? fallback : words.joined(separator: "-")
        var slug = base
        var counter = 2
        while taken.contains(slug) {
            slug = "\(base)-\(counter)"
            counter += 1
        }
        taken.insert(slug)
        return slug
    }
}
