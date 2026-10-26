import Foundation
import Testing

@testable import KitchenCore

@Suite("Food matching")
struct FoodMatchingTests {
    private static let catalog = FoodCatalog(
        sources: [], groups: [FoodGroup(id: "g", name: "G", direction: .notAssessed)],
        foods: [
            Food(id: "onion", name: "Zwiebel", group: "g", role: .aromatic),
            Food(id: "lentils", name: "Linsen", group: "g", role: .base),
            Food(id: "red-lentils", name: "Rote Linsen", group: "g", role: .base),
            Food(id: "chickpeas", name: "Kichererbsen, gegart", group: "g", role: .base),
            Food(id: "milk", name: "Milch", group: "g", role: .liquid),
            Food(id: "coconut-milk", name: "Kokosmilch", group: "g", role: .liquid),
            Food(id: "salmon", name: "Lachs", aliases: ["Lachsfilet"], group: "g", role: .base),
            Food(id: "cream", name: "Sahne", group: "g", role: .base),
            Food(id: "sour-cream", name: "Saure Sahne", aliases: ["Schmand"], group: "g", role: .base),
            Food(id: "pepper", name: "Paprika, rot", group: "g", role: .base),
            Food(id: "egg", name: "Ei", aliases: ["Eier"], group: "g", role: .base),
            Food(id: "a", name: "Pfeffer", group: "g", role: .seasoning),
            Food(id: "b", name: "Pfeffer", group: "g", role: .seasoning),
        ])

    @Test(arguments: [
        ("Zwiebeln, in Ringen", "onion" as FoodID?),
        ("rote LINSEN", "red-lentils"),
        ("Linsen", "lentils"),
        ("Kichererbsen, gegart", "chickpeas"),
        ("Kichererbsen aus der Dose", nil),
        ("1 TL Paprika, edelsüß", nil),
        ("200 g roten Linsen", "red-lentils"),
        ("saurer Sahne", "sour-cream"),
        ("Ingwer, ein daumengroßes Stück", nil),
        ("2 Eier", "egg"),
        ("Kokosmilch, cremig", "coconut-milk"),
        ("Vollmilch", nil),
        ("2 Lachsfilets", "salmon"),
        ("Schmand oder saure Sahne", "sour-cream"),
        ("Pfeffer", nil),
        ("", nil),
    ])
    func findsTheFoodWithTheLongestNameInTheIngredient(name: String, food: FoodID?) {
        #expect(Self.catalog.food(named: name) == food)
    }

    @Test func assignsOnlyMissingFoodsWithoutAnOriginal() {
        let recipe = Recipe(
            id: "r", name: "R", tag: "", baseServings: 1, totalMinutes: 1,
            ingredients: [
                Ingredient(id: "z", name: "Zwiebel", amount: .measured(1, .piece)),
                Ingredient(id: "l", name: "Linsen", amount: .measured(100, .gram), food: "red-lentils"),
                Ingredient(id: "x", name: "Etwas Unbekanntes", amount: .toTaste),
            ],
            steps: [])
        #expect(recipe.assigningFoods(from: Self.catalog).ingredients.map(\.food) == ["onion", "red-lentils", nil])
    }

    @Test func rematchesRenamedAndNewIngredientsAgainstTheOriginal() {
        let original = Recipe(
            id: "r", name: "R", tag: "", baseServings: 1, totalMinutes: 1,
            ingredients: [
                Ingredient(id: "a", name: "Zwiebel", amount: .measured(1, .piece), food: "onion"),
                Ingredient(id: "b", name: "Linsen", amount: .measured(100, .gram), food: "red-lentils"),
            ],
            steps: [])
        var edited = original
        edited.ingredients[0].name = "Lachs"
        edited.ingredients.append(Ingredient(id: "c", name: "Kokosmilch", amount: .measured(200, .gram), food: "milk"))
        let assigned = edited.assigningFoods(from: Self.catalog, comparedTo: original)
        #expect(assigned.ingredients.map(\.food) == ["salmon", "red-lentils", "coconut-milk"])
    }

    @Test(arguments: [
        ("Weiße Bohnen", "white-beans" as FoodID?),
        ("getrocknete weiße Bohnen", "white-beans"),
        ("Cannellini (Dose)", "white-beans-cooked"),
        ("Kidneybohnen (Dose), abgetropft", "kidney-beans-cooked"),
        ("Rote Kidneybohnen", "kidney-beans"),
        ("Koriander", nil),
    ])
    func bundledCatalogTellsRawFromCannedBeans(name: String, food: FoodID?) throws {
        #expect(try #require(FoodCatalog.shared).food(named: name) == food)
    }

    @Test func ingredientsChosenByHandKeepTheCooksChoice() throws {
        let original = Recipe(
            id: "r", name: "R", tag: "", baseServings: 1, totalMinutes: 1,
            ingredients: [Ingredient(id: "a", name: "Zwiebel", amount: .measured(1, .piece), food: "onion")],
            steps: [])
        var edited = original
        edited.ingredients[0].name = "Lachs"
        edited.ingredients[0].food = nil
        edited.ingredients[0].foodChosenByHand = true
        edited.ingredients.append(
            Ingredient(
                id: "b", name: "Zwiebel", amount: .measured(1, .piece), food: "salmon", foodChosenByHand: true))
        #expect(
            edited.assigningFoods(from: Self.catalog, comparedTo: original).ingredients.map(\.food) == [nil, "salmon"])
        // Also without an original, as when stored recipes load.
        #expect(edited.assigningFoods(from: Self.catalog).ingredients.map(\.food) == [nil, "salmon"])
        let json = try JSONEncoder().encode(edited.ingredients[1])
        #expect(try JSONDecoder().decode(Ingredient.self, from: json) == edited.ingredients[1])
    }

    /// Precision on real data: wherever the matcher finds a food for a bundled ingredient, it is the one the recipe
    /// declares, and it finds one for at least nine in ten ingredients.
    @Test func neverContradictsTheFoodsOfBundledRecipes() throws {
        let catalog = try #require(FoodCatalog.shared)
        let matcher = catalog.matcher
        var wrong: [String] = []
        var matched = 0
        var total = 0
        for recipe in try RecipeLibrary.bundled() {
            for ingredient in recipe.ingredients {
                total += 1
                guard let food = matcher.food(named: ingredient.name) else { continue }
                matched += 1
                guard food != ingredient.food else { continue }
                wrong.append("\(recipe.id)/\(ingredient.name): \(food) statt \(ingredient.food?.rawValue ?? "-")")
            }
        }
        #expect(wrong.isEmpty, "\(wrong.joined(separator: "\n"))")
        // Recall: almost every bundled ingredient name finds its food; a drop means a matcher or catalog regression.
        #expect(Double(matched) >= Double(total) * 0.9, "\(matched) von \(total)")
    }
}
