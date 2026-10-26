import Foundation

/// Accessories that go on or into the pot.
public enum Accessory: String, Sendable, Hashable, Codable, CaseIterable {
    case steamer
    case basket
    case whisk
}

/// A guided recipe for the multicooker.
///
/// `origin`, `references`, `authenticityChecks` and `variantOf` are optional in JSON; the other keys are required.
public struct Recipe: Sendable, Hashable, Identifiable {
    /// The JSON schema version this type reads and writes.
    public static let currentSchemaVersion = 1

    public let id: RecipeID
    public var name: String
    /// Short label above the name, for example "Mediterran · Ikaria".
    public var tag: String
    public var baseServings: Int
    /// Total time for the cook, including preparation.
    public var totalMinutes: Int
    public var ingredients: [Ingredient]
    public var steps: [Step]
    /// True once the recipe has been cooked on the real device and its settings were confirmed.
    public var verified: Bool
    /// The recipe this one was rewritten from for a health goal, nil for an original.
    public var variantOf: RecipeID?
    /// Cuisine and region of a traditional recipe, nil for the cook's own creations.
    public var origin: RecipeOrigin?
    public var references: [RecipeReference]
    /// What someone who knows the cuisine should confirm before the recipe counts as authentic, for example
    /// "Gewürze: Kreuzkümmel, Koriandersaat, Bockshornklee". Claude cannot vouch for authenticity (PLAN.md, 3c).
    public var authenticityChecks: [String]
    public var schemaVersion: Int

    public init(
        id: RecipeID, name: String, tag: String, baseServings: Int, totalMinutes: Int,
        ingredients: [Ingredient], steps: [Step], verified: Bool = false, variantOf: RecipeID? = nil,
        origin: RecipeOrigin? = nil, references: [RecipeReference] = [], authenticityChecks: [String] = [],
        schemaVersion: Int = Recipe.currentSchemaVersion
    ) {
        self.id = id
        self.name = name
        self.tag = tag
        self.baseServings = baseServings
        self.totalMinutes = totalMinutes
        self.ingredients = ingredients
        self.steps = steps
        self.verified = verified
        self.variantOf = variantOf
        self.origin = origin
        self.references = references
        self.authenticityChecks = authenticityChecks
        self.schemaVersion = schemaVersion
    }

    public func ingredient(_ id: IngredientID) -> Ingredient? {
        ingredients.first { $0.id == id }
    }
}

extension Recipe: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, tag, baseServings, totalMinutes, ingredients, steps, verified, variantOf, origin, references
        case authenticityChecks, schemaVersion
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(RecipeID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tag = try container.decode(String.self, forKey: .tag)
        baseServings = try container.decode(Int.self, forKey: .baseServings)
        totalMinutes = try container.decode(Int.self, forKey: .totalMinutes)
        ingredients = try container.decode([Ingredient].self, forKey: .ingredients)
        steps = try container.decode([Step].self, forKey: .steps)
        verified = try container.decode(Bool.self, forKey: .verified)
        variantOf = try container.decodeIfPresent(RecipeID.self, forKey: .variantOf)
        origin = try container.decodeIfPresent(RecipeOrigin.self, forKey: .origin)
        references = try container.decodeIfPresent([RecipeReference].self, forKey: .references) ?? []
        authenticityChecks = try container.decodeIfPresent([String].self, forKey: .authenticityChecks) ?? []
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tag, forKey: .tag)
        try container.encode(baseServings, forKey: .baseServings)
        try container.encode(totalMinutes, forKey: .totalMinutes)
        try container.encode(verified, forKey: .verified)
        try container.encodeIfPresent(variantOf, forKey: .variantOf)
        try container.encodeIfPresent(origin, forKey: .origin)
        if !references.isEmpty {
            try container.encode(references, forKey: .references)
        }
        if !authenticityChecks.isEmpty {
            try container.encode(authenticityChecks, forKey: .authenticityChecks)
        }
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(steps, forKey: .steps)
    }
}

/// Something the cook can use instead of an ingredient they lack.
public struct Substitute: Sendable, Hashable, Codable {
    public var name: String
    /// Amount of the substitute per unit of the original, for example 0.5 for half as much.
    public var ratio: Double
    /// What changes, for example "milder, etwas süßer".
    public var note: String?

    public init(name: String, ratio: Double = 1, note: String? = nil) {
        self.name = name
        self.ratio = ratio
        self.note = note
    }
}

/// One ingredient with its amount for the recipe's base servings.
///
/// JSON shape: `{"id": "linsen", "name": "Rote Linsen", "quantity": 200, "unit": "g"}`.
/// Without `quantity` the amount is "to taste". `scales` and `eaten` default to true, `substitutes` to none.
/// `food` points at the `FoodCatalog` entry, for example `"food": "red-lentils"`.
public struct Ingredient: Sendable, Hashable, Identifiable {
    public let id: IngredientID
    public var name: String
    public var amount: Amount
    /// The catalog food this ingredient is, nil until it is mapped.
    public var food: FoodID?
    /// Extra detail shown next to the amount, for example "à 150 g".
    public var note: String?
    /// False for things like a bay leaf, where the amount stays the same for more servings.
    public var scales: Bool
    /// False for things that leave the dish before eating, like steaming water or a bay leaf; they do not count
    /// towards nutrition.
    public var eaten: Bool
    public var substitutes: [Substitute]
    /// True when the cook chose `food` (or no food) by hand; matching by name then leaves it alone.
    public var foodChosenByHand: Bool

    public init(
        id: IngredientID, name: String, amount: Amount, food: FoodID? = nil, note: String? = nil,
        scales: Bool = true, eaten: Bool = true, substitutes: [Substitute] = [], foodChosenByHand: Bool = false
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.food = food
        self.note = note
        self.scales = scales
        self.eaten = eaten
        self.substitutes = substitutes
        self.foodChosenByHand = foodChosenByHand
    }

    /// The amount for `servings`, given the recipe was written for `base` servings.
    public func amount(from base: Int, to servings: Int) -> Amount {
        scales ? amount.scaled(from: base, to: servings) : amount
    }

    /// Each substitute with the amount to use instead of this ingredient for `servings`.
    public func substitutions(from base: Int, to servings: Int) -> [(substitute: Substitute, amount: Amount)] {
        let original = amount(from: base, to: servings)
        return substitutes.map { substitute in
            switch original {
            case .measured(let value, let unit):
                return (substitute, .measured(value * substitute.ratio, unit))
            case .toTaste:
                return (substitute, .toTaste)
            }
        }
    }
}

extension Ingredient: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit, food, note, scales, eaten, substitutes, foodChosenByHand
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(IngredientID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        if let quantity = try container.decodeIfPresent(Double.self, forKey: .quantity) {
            amount = .measured(quantity, try container.decode(MeasureUnit.self, forKey: .unit))
        } else {
            amount = .toTaste
        }
        food = try container.decodeIfPresent(FoodID.self, forKey: .food)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        scales = try container.decodeIfPresent(Bool.self, forKey: .scales) ?? true
        eaten = try container.decodeIfPresent(Bool.self, forKey: .eaten) ?? true
        substitutes = try container.decodeIfPresent([Substitute].self, forKey: .substitutes) ?? []
        foodChosenByHand = try container.decodeIfPresent(Bool.self, forKey: .foodChosenByHand) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        if case .measured(let quantity, let unit) = amount {
            try container.encode(quantity, forKey: .quantity)
            try container.encode(unit, forKey: .unit)
        }
        try container.encodeIfPresent(food, forKey: .food)
        try container.encodeIfPresent(note, forKey: .note)
        if !scales {
            try container.encode(false, forKey: .scales)
        }
        if !eaten {
            try container.encode(false, forKey: .eaten)
        }
        if !substitutes.isEmpty {
            try container.encode(substitutes, forKey: .substitutes)
        }
        if foodChosenByHand {
            try container.encode(true, forKey: .foodChosenByHand)
        }
    }
}

/// One step of the guided cook.
public struct Step: Sendable, Hashable, Codable, Identifiable {
    public let id: StepID
    /// Short phase label, for example "Anschwitzen".
    public var phase: String
    public var text: String
    public var note: String?
    /// Ingredients that go into the pot in this step.
    public var ingredientIDs: [IngredientID]
    public var setting: DeviceSetting?
    public var accessory: Accessory?
    /// True when this step starts over in an empty, clean pot, for example a side dish after the main dish.
    public var freshPot: Bool

    public init(
        id: StepID, phase: String, text: String, note: String? = nil, ingredientIDs: [IngredientID] = [],
        setting: DeviceSetting? = nil, accessory: Accessory? = nil, freshPot: Bool = false
    ) {
        self.id = id
        self.phase = phase
        self.text = text
        self.note = note
        self.ingredientIDs = ingredientIDs
        self.setting = setting
        self.accessory = accessory
        self.freshPot = freshPot
    }

    private enum CodingKeys: String, CodingKey {
        case id, phase, text, note, ingredientIDs, setting, accessory, freshPot
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(StepID.self, forKey: .id)
        phase = try container.decode(String.self, forKey: .phase)
        text = try container.decode(String.self, forKey: .text)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        ingredientIDs = try container.decodeIfPresent([IngredientID].self, forKey: .ingredientIDs) ?? []
        setting = try container.decodeIfPresent(DeviceSetting.self, forKey: .setting)
        accessory = try container.decodeIfPresent(Accessory.self, forKey: .accessory)
        freshPot = try container.decodeIfPresent(Bool.self, forKey: .freshPot) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(phase, forKey: .phase)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(note, forKey: .note)
        if !ingredientIDs.isEmpty {
            try container.encode(ingredientIDs, forKey: .ingredientIDs)
        }
        try container.encodeIfPresent(setting, forKey: .setting)
        try container.encodeIfPresent(accessory, forKey: .accessory)
        if freshPot {
            try container.encode(true, forKey: .freshPot)
        }
    }

    /// How long the step's timer runs, if it has one.
    public var timerDuration: Duration? {
        guard let duration = setting?.duration, duration > .zero else { return nil }
        return duration
    }
}
