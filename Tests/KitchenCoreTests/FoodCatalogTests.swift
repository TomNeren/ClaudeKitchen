import Foundation
import Testing

@testable import KitchenCore

@Suite("Food catalog")
struct FoodCatalogTests {
    @Test func bundledCatalogIsConsistent() throws {
        let catalog = try FoodCatalog.bundled()
        #expect(catalog.issues().isEmpty, "\(catalog.issues())")
        #expect(!catalog.foods.isEmpty)
    }

    @Test func everyIngredientOfEveryBundledRecipeIsMappedAndWeighable() throws {
        let catalog = try FoodCatalog.bundled()
        for recipe in try RecipeLibrary.bundled() {
            let issues = catalog.issues(in: recipe)
            #expect(issues.isEmpty, "\(recipe.id): \(issues)")
        }
    }

    @Test func reportsCatalogInconsistencies() {
        let catalog = FoodCatalog(
            sources: [EvidenceSource(id: "s", citation: "S", year: 2024)],
            groups: [
                FoodGroup(id: "g", name: "G", direction: .favorable, sourceIDs: ["missing"]),
                FoodGroup(id: "g", name: "G2", direction: .limit),
            ],
            foods: [
                Food(id: "f", name: "F", group: "nowhere", role: .base),
                Food(id: "f", name: "F2", group: "g", role: .base, gramsPerUnit: [.piece: 0, .gram: 1, .clove: 3]),
            ])
        #expect(
            catalog.issues() == [
                .duplicateGroup("g"), .duplicateFood("f"),
                .unknownSource(group: "g", source: "missing"), .assessedWithoutSource("g"),
                .unknownGroup(food: "f", group: "nowhere"),
                .invalidWeight(food: "f", unit: .piece), .invalidWeight(food: "f", unit: .gram),
            ])
    }

    @Test func reportsUnmappedUnknownAndUnweighableIngredients() {
        let catalog = FoodCatalog(
            sources: [], groups: [FoodGroup(id: "veg", name: "Gemüse", direction: .notAssessed)],
            foods: [Food(id: "onion", name: "Zwiebel", group: "veg", role: .aromatic)])
        let recipe = Recipe(
            id: "r", name: "R", tag: "", baseServings: 2, totalMinutes: 10,
            ingredients: [
                Ingredient(id: "a", name: "A", amount: .measured(100, .gram)),
                Ingredient(id: "b", name: "B", amount: .measured(1, .gram), food: "ghost"),
                Ingredient(id: "c", name: "Zwiebel", amount: .measured(1, .piece), food: "onion"),
                Ingredient(id: "d", name: "Zwiebel", amount: .toTaste, food: "onion"),
            ],
            steps: [])
        #expect(
            catalog.issues(in: recipe) == [
                .unmappedIngredient("a"), .unknownFood(ingredient: "b", food: "ghost"),
                .missingWeight(ingredient: "c", unit: .piece),
            ])
    }

    @Test(arguments: [
        (Amount.measured(250, .gram), 250.0 as Double?),
        (.measured(2, .piece), 200),
        (.measured(1, .teaspoon), nil),
        (.toTaste, nil),
    ])
    func convertsAmountsToGrams(amount: Amount, grams: Double?) {
        let onion = Food(id: "onion", name: "Zwiebel", group: "veg", role: .aromatic, gramsPerUnit: [.piece: 100])
        #expect(onion.grams(of: amount) == grams)
    }

    @Test func foodRoundTripsThroughJSONWithUnitKeys() throws {
        let food = Food(id: "salt", name: "Salz", group: "salt", role: .seasoning, gramsPerUnit: [.teaspoon: 6])
        let json = try #require(String(data: JSONEncoder().encode(food), encoding: .utf8))
        #expect(json.contains("\"TL\":6"))
        #expect(try JSONDecoder().decode(Food.self, from: Data(json.utf8)) == food)
    }

    @Test func ingredientWithoutFoodStillDecodes() throws {
        let json = #"{"id": "x", "name": "X", "quantity": 5, "unit": "g"}"#
        let ingredient = try JSONDecoder().decode(Ingredient.self, from: Data(json.utf8))
        #expect(ingredient.food == nil)
    }

    @Test func rejectsNewerSchemaVersion() {
        let json = #"{"schemaVersion": 99, "sources": [], "groups": [], "foods": []}"#
        #expect(throws: FoodCatalog.LoadError.unsupportedSchemaVersion(99)) {
            try FoodCatalog.decode(Data(json.utf8))
        }
    }
}
