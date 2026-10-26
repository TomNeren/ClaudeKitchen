import Foundation

/// A recipe as the import model returns it, before ids are assigned and the device check runs.
/// Mirrors `ClaudeRecipeImport.schema` exactly; optional values arrive as JSON `null`. Internal: the public API is
/// `ClaudeRecipeImport.recipe(fromResponse:id:)`, which hands out a `Recipe`.
struct RecipeDraft: Sendable, Equatable, Codable {
    struct Ingredient: Sendable, Equatable, Codable {
        var name: String
        var quantity: Double?
        /// A `MeasureUnit` raw value or `ml`; null with a quantity means pieces, null without one "to taste".
        var unit: String?
        var note: String?
        var scales: Bool
    }

    struct Setting: Sendable, Equatable, Codable {
        /// `manual`, `steam`, `knead`, `sousVide`, `yogurt` or `weigh`.
        var program: String
        var celsius: Int?
        var steam: Bool
        var speed: Int?
        var reverse: Bool
        var seconds: Int?
    }

    struct Step: Sendable, Equatable, Codable {
        var phase: String
        var text: String
        var note: String?
        /// Indexes into `ingredients` of what goes in at this step.
        var ingredientIndexes: [Int]
        var setting: Setting?
        /// `steamer`, `basket`, `whisk` or null.
        var accessory: String?
        /// True when this step starts over in an empty, clean pot.
        var freshPot: Bool
    }

    var name: String
    var tag: String
    var baseServings: Int
    var totalMinutes: Int
    var ingredients: [Ingredient]
    var steps: [Step]
}

/// Why a draft could not become a recipe.
public enum RecipeDraftError: Error, Equatable {
    case unknownUnit(ingredient: String, unit: String)
    case unknownProgram(step: Int, program: String)
    case unknownAccessory(step: Int, accessory: String)
    case ingredientIndexOutOfRange(step: Int, index: Int)
}

extension RecipeDraft {
    /// Turns the draft into a recipe with generated ids. Millilitres count as grams (water-like density), which is
    /// how the fill estimate treats them anyway. The result still has to pass `DeviceProfile.validate`.
    func recipe(id: RecipeID) throws -> Recipe {
        var ingredientIDs: [IngredientID] = []
        var usedIDs: Set<String> = []
        let ingredients = try self.ingredients.map { draft -> KitchenCore.Ingredient in
            let id = IngredientID(Slug.unique(draft.name, fallback: "zutat", taken: &usedIDs))
            ingredientIDs.append(id)
            return KitchenCore.Ingredient(
                id: id, name: draft.name, amount: try Self.amount(of: draft), note: draft.note, scales: draft.scales)
        }
        let steps = try self.steps.enumerated().map { index, draft -> KitchenCore.Step in
            let number = index + 1
            let stepIngredients = try draft.ingredientIndexes.map { ingredientIndex -> IngredientID in
                guard ingredientIDs.indices.contains(ingredientIndex) else {
                    throw RecipeDraftError.ingredientIndexOutOfRange(step: number, index: ingredientIndex)
                }
                return ingredientIDs[ingredientIndex]
            }
            let accessory = try draft.accessory.map { name in
                guard let accessory = Accessory(rawValue: name) else {
                    throw RecipeDraftError.unknownAccessory(step: number, accessory: name)
                }
                return accessory
            }
            return KitchenCore.Step(
                id: StepID("s\(number)"), phase: draft.phase, text: draft.text, note: draft.note,
                ingredientIDs: stepIngredients,
                setting: try draft.setting.map { try Self.setting(of: $0, step: number) },
                accessory: accessory, freshPot: draft.freshPot)
        }
        return Recipe(
            id: id, name: name, tag: tag, baseServings: baseServings, totalMinutes: totalMinutes,
            ingredients: ingredients, steps: steps, verified: false)
    }

    private static func amount(of ingredient: Ingredient) throws -> Amount {
        guard let quantity = ingredient.quantity else { return .toTaste }
        // A count without a unit ("3 Eier") is pieces, not "to taste".
        guard let unit = ingredient.unit else { return .measured(quantity, .piece) }
        if unit == "ml" { return .measured(quantity, .gram) }
        guard let measure = MeasureUnit(rawValue: unit) else {
            throw RecipeDraftError.unknownUnit(ingredient: ingredient.name, unit: unit)
        }
        return .measured(quantity, measure)
    }

    private static func setting(of draft: Setting, step: Int) throws -> DeviceSetting {
        guard let program = Program(rawValue: draft.program) else {
            throw RecipeDraftError.unknownProgram(step: step, program: draft.program)
        }
        let heat: Heat? = draft.steam ? .steam : draft.celsius.map { .celsius($0) }
        let rotation: Rotation? = draft.speed.map { draft.reverse ? .reverse(speed: $0) : .forward(speed: $0) }
        return DeviceSetting(
            program: program, heat: heat, rotation: rotation, duration: draft.seconds.map { .seconds($0) })
    }

}
