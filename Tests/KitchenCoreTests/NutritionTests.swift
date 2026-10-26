import Foundation
import Testing

@testable import KitchenCore

@Suite("Nutrition")
struct NutritionTests {
    private static let lentils = Nutrients(
        fdcID: 1, kcal: 358, protein: 24, fat: 2, saturatedFat: 0.4, carbohydrate: 63, fiber: 11,
        sodiumMilligrams: 7)
    private static let onion = Nutrients(
        fdcID: 2, kcal: 40, protein: 1, fat: 0.1, saturatedFat: 0, carbohydrate: 9, fiber: nil, sodiumMilligrams: 4)

    private static let catalog = FoodCatalog(
        sources: [], groups: [FoodGroup(id: "g", name: "G", direction: .notAssessed)],
        foods: [
            Food(id: "lentils", name: "Linsen", group: "g", role: .base, nutrients: lentils),
            Food(
                id: "onion", name: "Zwiebel", group: "g", role: .aromatic, gramsPerUnit: [.piece: 100], nutrients: onion
            ),
            Food(id: "salt", name: "Salz", group: "g", role: .seasoning),
        ])

    @Test func sumsNutrientsPerServingFromScaledAmounts() {
        let recipe = Recipe(
            id: "r", name: "R", tag: "", baseServings: 2, totalMinutes: 10,
            ingredients: [
                Ingredient(id: "a", name: "Linsen", amount: .measured(200, .gram), food: "lentils"),
                Ingredient(id: "b", name: "Zwiebel", amount: .measured(1, .piece), food: "onion"),
                Ingredient(id: "c", name: "Salz", amount: .toTaste, food: "salt"),
                Ingredient(id: "d", name: "Zwiebel, fest", amount: .measured(1, .piece), food: "onion", scales: false),
                Ingredient(id: "e", name: "Unbekannt", amount: .measured(5, .gram)),
            ],
            steps: [])
        let facts = Self.catalog.nutritionPerServing(of: recipe)
        // 100 g lentils + 50 g onion per serving, plus the non-scaling 100 g onion counted in full.
        #expect(abs(facts.kcal - (358 + 20 + 40)) < 0.001)
        #expect(abs(facts.carbohydrate - (63 + 4.5 + 9)) < 0.001)
        #expect(abs(facts.fiber - 11) < 0.001)
        #expect(facts.uncounted == ["c", "e"])
    }

    @Test(arguments: [
        (
            Nutrients(
                fdcID: 1, kcal: 1, protein: 1, fat: 1, saturatedFat: 2, carbohydrate: 1, fiber: 0, sodiumMilligrams: 0),
            false
        ),
        (
            Nutrients(
                fdcID: 1, kcal: 1, protein: 60, fat: 30, saturatedFat: 1, carbohydrate: 30, fiber: 0,
                sodiumMilligrams: 0), false
        ),
        (
            Nutrients(
                fdcID: 1, kcal: -1, protein: 1, fat: 1, saturatedFat: 0, carbohydrate: 1, fiber: nil,
                sodiumMilligrams: 0), false
        ),
        (
            Nutrients(
                fdcID: 1, kcal: 884, protein: 0, fat: 100, saturatedFat: 14, carbohydrate: 0, fiber: 0,
                sodiumMilligrams: 2), true
        ),
    ])
    func plausibility(nutrients: Nutrients, plausible: Bool) {
        #expect(nutrients.isPlausible == plausible)
    }

    @Test func reportsMissingAndImplausibleNutrients() {
        let bad = Nutrients(
            fdcID: 3, kcal: 1, protein: 1, fat: 1, saturatedFat: 5, carbohydrate: 1, fiber: 0, sodiumMilligrams: 0)
        let catalog = FoodCatalog(
            sources: [], groups: [FoodGroup(id: "g", name: "G", direction: .notAssessed)],
            foods: [
                Food(id: "base", name: "B", group: "g", role: .base),
                Food(id: "spice", name: "S", group: "g", role: .seasoning),
                Food(id: "odd", name: "O", group: "g", role: .fat, nutrients: bad),
            ])
        #expect(catalog.issues() == [.missingNutrients("base"), .implausibleNutrients("odd")])
    }

    @Test func everyBundledRecipeHasNutritionForAllButSeasoningsToTaste() throws {
        let catalog = try FoodCatalog.bundled()
        for recipe in try RecipeLibrary.bundled() {
            let facts = catalog.nutritionPerServing(of: recipe)
            #expect(facts.kcal > 100, "\(recipe.id)")
            for id in facts.uncounted {
                let ingredient = try #require(recipe.ingredient(id))
                let food = try #require(catalog.food(for: ingredient))
                #expect(food.role == .seasoning, "\(recipe.id): \(id) not counted")
            }
        }
    }

    @Test func nutrientsRoundTripThroughFoodJSON() throws {
        let food = Food(id: "onion", name: "Zwiebel", group: "g", role: .aromatic, nutrients: Self.onion)
        let decoded = try JSONDecoder().decode(Food.self, from: JSONEncoder().encode(food))
        #expect(decoded == food)
    }
}
