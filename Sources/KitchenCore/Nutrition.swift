import Foundation

/// Nutrients per 100 g of a food, taken from one USDA FoodData Central entry.
public struct Nutrients: Sendable, Hashable, Codable {
    /// The FoodData Central entry the values come from, for checking them against the source.
    public var fdcID: Int
    public var kcal: Double
    public var protein: Double
    public var fat: Double
    public var saturatedFat: Double
    public var carbohydrate: Double
    /// Nil where the source has no value.
    public var fiber: Double?
    public var sodiumMilligrams: Double

    public init(
        fdcID: Int, kcal: Double, protein: Double, fat: Double, saturatedFat: Double, carbohydrate: Double,
        fiber: Double?, sodiumMilligrams: Double
    ) {
        self.fdcID = fdcID
        self.kcal = kcal
        self.protein = protein
        self.fat = fat
        self.saturatedFat = saturatedFat
        self.carbohydrate = carbohydrate
        self.fiber = fiber
        self.sodiumMilligrams = sodiumMilligrams
    }

    /// True when no value is negative, saturated fat fits into fat, and the macronutrients fit into 100 g.
    public var isPlausible: Bool {
        let values = [kcal, protein, fat, saturatedFat, carbohydrate, fiber ?? 0, sodiumMilligrams]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return false }
        return saturatedFat <= fat && protein + fat + carbohydrate <= 100.5
    }
}

/// Nutrient totals for an amount of food, for example one serving of a recipe.
public struct NutritionFacts: Sendable, Hashable {
    public var kcal: Double = 0
    public var protein: Double = 0
    public var fat: Double = 0
    public var saturatedFat: Double = 0
    public var carbohydrate: Double = 0
    public var fiber: Double = 0
    public var sodiumMilligrams: Double = 0
    /// Ingredients left out of the totals: "to taste", unmapped, without weight, or without nutrients.
    public var uncounted: [IngredientID] = []

    public init() {}

    mutating func add(_ nutrients: Nutrients, grams: Double) {
        let factor = grams / 100
        kcal += nutrients.kcal * factor
        protein += nutrients.protein * factor
        fat += nutrients.fat * factor
        saturatedFat += nutrients.saturatedFat * factor
        carbohydrate += nutrients.carbohydrate * factor
        fiber += (nutrients.fiber ?? 0) * factor
        sodiumMilligrams += nutrients.sodiumMilligrams * factor
    }
}

extension FoodCatalog {
    /// Nutrients of one serving of `recipe`, with amounts scaled like the cook sees them.
    public func nutritionPerServing(of recipe: Recipe) -> NutritionFacts {
        var facts = NutritionFacts()
        for ingredient in recipe.ingredients {
            guard let food = food(for: ingredient), let nutrients = food.nutrients,
                let grams = food.grams(of: ingredient.amount(from: recipe.baseServings, to: 1))
            else {
                facts.uncounted.append(ingredient.id)
                continue
            }
            facts.add(nutrients, grams: grams)
        }
        return facts
    }
}
