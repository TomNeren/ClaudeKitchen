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

    /// True when no value is negative, saturated fat fits into fat, fiber into carbohydrate (USDA counts it in
    /// "carbohydrate by difference"), the macronutrients into 100 g, and energy stays below pure fat (900 kcal).
    public var isPlausible: Bool {
        let values = [kcal, protein, fat, saturatedFat, carbohydrate, fiber ?? 0, sodiumMilligrams]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return false }
        return saturatedFat <= fat && (fiber ?? 0) <= carbohydrate && protein + fat + carbohydrate <= 100.5
            && kcal <= 900
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
    /// Ingredients that are not eaten are left out on purpose and not listed.
    public var uncounted: [IngredientID] = []
    /// Counted ingredients whose source has no fiber value, so `fiber` is a lower bound.
    public var fiberUnknown: [IngredientID] = []

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
    /// Nutrients of one serving of `recipe`: the whole recipe at its base servings, divided by them. Ingredients
    /// that do not scale are shared across the servings like everything else.
    public func nutritionPerServing(of recipe: Recipe) -> NutritionFacts {
        var facts = NutritionFacts()
        guard recipe.baseServings > 0 else {
            facts.uncounted = recipe.ingredients.map(\.id)
            return facts
        }
        let share = 1 / Double(recipe.baseServings)
        for ingredient in recipe.ingredients where ingredient.eaten {
            guard let food = food(for: ingredient), let nutrients = food.nutrients,
                let grams = food.grams(of: ingredient.amount)
            else {
                facts.uncounted.append(ingredient.id)
                continue
            }
            facts.add(nutrients, grams: grams * share)
            if nutrients.fiber == nil {
                facts.fiberUnknown.append(ingredient.id)
            }
        }
        return facts
    }
}
