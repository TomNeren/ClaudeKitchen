import Foundation
import Testing

@testable import KitchenCore

@Suite("Shopping list and pantry")
struct ShoppingListTests {
    private static let catalog = FoodCatalog(
        sources: [],
        groups: [
            FoodGroup(id: "veg", name: "Gemüse", direction: .notAssessed, aisle: .produce),
            FoodGroup(id: "dry", name: "Trocken", direction: .notAssessed, aisle: .dryGoods),
            FoodGroup(id: "spice", name: "Gewürz", direction: .notAssessed, aisle: .spices),
            FoodGroup(id: "water", name: "Wasser", direction: .notAssessed),
        ],
        foods: [
            Food(id: "onion", name: "Zwiebel", group: "veg", role: .aromatic, gramsPerUnit: [.piece: 100]),
            Food(id: "lentils", name: "Rote Linsen", group: "dry", role: .base),
            Food(id: "rice", name: "Reis", group: "dry", role: .base),
            Food(id: "salt", name: "Salz", group: "spice", role: .seasoning),
            Food(id: "cumin", name: "Kreuzkümmel", group: "spice", role: .seasoning, gramsPerUnit: [.teaspoon: 2]),
            Food(id: "dill", name: "Dill", group: "spice", role: .seasoning, aisle: .produce),
            Food(id: "water", name: "Wasser", group: "water", role: .liquid),
        ])

    private static func recipe(_ id: RecipeID, base: Int = 2, _ ingredients: [Ingredient]) -> Recipe {
        Recipe(id: id, name: "R", tag: "", baseServings: base, totalMinutes: 10, ingredients: ingredients, steps: [])
    }

    private static func ingredient(_ food: FoodID?, _ amount: Amount, name: String? = nil) -> Ingredient {
        Ingredient(id: IngredientID(food?.rawValue ?? "x"), name: name ?? "N", amount: amount, food: food)
    }

    private static let dal = recipe(
        "dal",
        [
            ingredient("lentils", .measured(200, .gram)), ingredient("onion", .measured(1, .piece)),
            ingredient("cumin", .measured(1, .teaspoon)), ingredient("salt", .toTaste),
            ingredient("water", .measured(800, .gram)),
        ])

    private static func list(_ plans: [(Recipe, Int)], _ pantry: Pantry = Pantry()) -> ShoppingList {
        ShoppingList(plans: plans.map { (recipe: $0.0, servings: $0.1) }, pantry: pantry, catalog: catalog)
    }

    private static func item(_ list: ShoppingList, _ food: FoodID) -> ShoppingList.Item? {
        list.items.first { $0.food == food }
    }

    @Test func buysWhatThePlansNeedMinusTheStock() {
        let pantry = Pantry(items: [PantryItem(food: "lentils", stock: .grams(150))])
        let list = Self.list([(Self.dal, 2)], pantry)
        #expect(Self.item(list, "lentils")?.quantity == .grams(50, pieces: nil))
        #expect(Self.item(list, "lentils")?.reason == .needed)
        #expect(Self.item(list, "lentils")?.recipes == ["dal"])
        #expect(Self.item(list, "water") == nil)
    }

    @Test func mergesRecipesAndScalesServingsWithPieces() {
        let soup = Self.recipe("soup", base: 4, [Self.ingredient("onion", .measured(2, .piece))])
        let list = Self.list([(Self.dal, 4), (soup, 4)])
        #expect(Self.item(list, "onion")?.quantity == .grams(400, pieces: 4))
        #expect(Self.item(list, "onion")?.recipes == ["dal", "soup"])
    }

    @Test func topsUpToTheMinimumAndRestocksUnplannedBasics() {
        let pantry = Pantry(items: [
            PantryItem(food: "lentils", stock: .grams(300), minimumGrams: 500),
            PantryItem(food: "rice", stock: .grams(100), minimumGrams: 500),
        ])
        let list = Self.list([(Self.dal, 2)], pantry)
        #expect(Self.item(list, "lentils")?.quantity == .grams(400, pieces: nil))
        #expect(Self.item(list, "lentils")?.reason == .belowMinimum)
        #expect(Self.item(list, "rice")?.quantity == .grams(400, pieces: nil))
        #expect(Self.item(list, "rice")?.recipes == [])
    }

    @Test func listsSeasoningsByLevel() {
        let unknown = Self.list([(Self.dal, 2)])
        #expect(Self.item(unknown, "cumin")?.quantity == .level)
        #expect(Self.item(unknown, "cumin")?.reason == .unknownStock)
        let pantry = Pantry(items: [
            PantryItem(food: "cumin", stock: .level(.low)), PantryItem(food: "salt", stock: .level(.available)),
            PantryItem(food: "dill", stock: .level(.empty)),
        ])
        let known = Self.list([(Self.dal, 2)], pantry)
        #expect(Self.item(known, "cumin")?.reason == .runningLow)
        #expect(Self.item(known, "salt") == nil)
        #expect(Self.item(known, "dill")?.reason == .belowMinimum)
        #expect(Self.list([], Pantry(items: [PantryItem(food: "cumin", stock: .level(.low))])).items.isEmpty)
    }

    @Test func freshHerbsCountInGramsLikeProduce() {
        let tzatziki = Self.recipe("t", [Self.ingredient("dill", .measured(10, .gram))])
        #expect(Self.item(Self.list([(tzatziki, 2)]), "dill")?.quantity == .grams(10, pieces: nil))
    }

    @Test func unknownIngredientsAndUnweighableAmountsStayOnTheList() {
        let odd = Self.recipe(
            "odd",
            [
                Self.ingredient(nil, .measured(1, .piece), name: "Drachenfrucht"),
                Self.ingredient("onion", .toTaste),
            ])
        let list = Self.list([(odd, 2)])
        #expect(
            list.items.first { $0.name == "Drachenfrucht" }
                == .init(
                    food: nil, name: "Drachenfrucht", aisle: .other, quantity: .unknown, reason: .needed,
                    recipes: ["odd"]))
        #expect(Self.item(list, "onion")?.quantity == .unknown)
    }

    @Test func sortsByAisleThenName() {
        let list = Self.list([(Self.dal, 2)])
        #expect(list.items.map(\.aisle) == list.items.map(\.aisle).sorted())
        #expect(list.items.first?.aisle == .produce)
    }

    @Test(arguments: [(7.0, 10.0), (100, 100), (101, 150), (1000, 1000), (1001, 1100)])
    func roundsUpToShoppingSteps(grams: Double, rounded: Double) {
        let food = Food(id: "f", name: "F", group: "dry", role: .base)
        #expect(ShoppingList.quantity(grams: grams, of: food) == .grams(rounded, pieces: nil))
    }

    @Test func cookingTakesGramsOutButLeavesLevelsAndUnknownFoods() {
        let pantry = Pantry(items: [
            PantryItem(food: "lentils", stock: .grams(150), minimumGrams: 500),
            PantryItem(food: "onion", stock: .grams(300)), PantryItem(food: "cumin", stock: .level(.available)),
        ])
        let after = pantry.cooking(Self.dal, servings: 2, catalog: Self.catalog)
        #expect(after["lentils"] == PantryItem(food: "lentils", stock: .grams(0), minimumGrams: 500))
        #expect(after["onion"]?.stock == .grams(200))
        #expect(after["cumin"]?.stock == .level(.available))
        #expect(after["salt"] == nil)
    }

    @Test func buyingAddsGramsAndRefillsSeasonings() {
        let pantry = Pantry(items: [
            PantryItem(food: "lentils", stock: .grams(150), minimumGrams: 500),
            PantryItem(food: "cumin", stock: .level(.empty)),
        ])
        let list = Self.list([(Self.dal, 2)], pantry)
        let after = pantry.buying(list)
        #expect(after["lentils"] == PantryItem(food: "lentils", stock: .grams(700), minimumGrams: 500))
        #expect(after["cumin"]?.stock == .level(.available))
        #expect(after["onion"]?.stock == .grams(100))
        #expect(after["salt"]?.stock == .level(.available))
    }

    @Test func pantryKeepsOneItemPerFoodAndRoundTrips() throws {
        var pantry = Pantry(items: [
            PantryItem(food: "rice", stock: .grams(1)), PantryItem(food: "rice", stock: .grams(2)),
        ])
        #expect(pantry.items == [PantryItem(food: "rice", stock: .grams(2))])
        pantry["rice"] = nil
        #expect(pantry.items.isEmpty)
        let full = Pantry(items: [
            PantryItem(food: "rice", stock: .grams(500), minimumGrams: 250),
            PantryItem(food: "salt", stock: .level(.low)),
        ])
        #expect(try JSONDecoder().decode(Pantry.self, from: JSONEncoder().encode(full)) == full)
    }

    @Test func everyBundledFoodButWaterHasAnAisle() throws {
        let catalog = try #require(FoodCatalog.shared)
        let missing = catalog.foods.filter { $0.id != Food.water && catalog.aisle(of: $0) == .other }.map(\.id)
        #expect(missing.isEmpty, "\(missing)")
    }

    @Test func aBundledWeekBuildsAList() throws {
        let catalog = try #require(FoodCatalog.shared)
        let recipes = try RecipeLibrary.bundled().prefix(5).map { (recipe: $0, servings: 2) }
        let list = ShoppingList(plans: Array(recipes), pantry: Pantry(), catalog: catalog)
        #expect(!list.items.isEmpty)
        #expect(!list.items.contains { $0.food == Food.water })
    }
}
