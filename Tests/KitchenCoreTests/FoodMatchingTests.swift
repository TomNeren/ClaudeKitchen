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
            Food(id: "a", name: "Pfeffer", group: "g", role: .seasoning),
            Food(id: "b", name: "Pfeffer", group: "g", role: .seasoning),
        ])

    @Test(arguments: [
        ("Zwiebeln, in Ringen", "onion" as FoodID?),
        ("rote LINSEN", "red-lentils"),
        ("Linsen", "lentils"),
        ("Kichererbsen aus der Dose", "chickpeas"),
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

    /// Precision on real data: wherever the matcher finds a food for a bundled ingredient, it is the one the recipe
    /// declares. Ingredients it cannot match are fine; wrong matches are not.
    @Test func neverContradictsTheFoodsOfBundledRecipes() throws {
        let catalog = try #require(FoodCatalog.shared)
        var wrong: [String] = []
        for recipe in try RecipeLibrary.bundled() {
            for ingredient in recipe.ingredients {
                guard let matched = catalog.food(named: ingredient.name), matched != ingredient.food else { continue }
                wrong.append("\(recipe.id)/\(ingredient.name): \(matched) statt \(ingredient.food?.rawValue ?? "-")")
            }
        }
        #expect(wrong.isEmpty, "\(wrong.joined(separator: "\n"))")
    }
}
