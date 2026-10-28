import Foundation
import Testing

@testable import KitchenCore

@Suite("Spice guide")
struct SpiceGuideTests {
    /// Seasonings every German kitchen knows; everything else a bundled recipe uses needs an entry.
    static let everyday: Set<FoodID> = [
        "salt", "black-pepper", "white-pepper", "sugar", "honey", "bay-leaf", "basil", "dill", "parsley",
        "rosemary", "oregano-dried", "dried-mint", "cinnamon", "chili-powder", "coriander-ground", "coriander-leaves",
        "lemon", "lime", "red-wine-vinegar", "tomato-paste", "soy-sauce", "sesame-seeds", "kimchi-juice",
        "garlic", "onion", "shallot", "spring-onion", "ginger", "red-chili", "green-chili",
    ]

    @Test func loadsAndPointsAtCatalogFoods() throws {
        let guide = try SpiceGuide.bundled()
        let catalog = try FoodCatalog.bundled()
        let known = Set(catalog.foods.map(\.id))
        #expect(!guide.entries.isEmpty)
        for entry in guide.entries {
            #expect(known.contains(entry.food), "\(entry.food) is not in the food catalog")
            #expect(!entry.summary.isEmpty && !entry.taste.isEmpty, "\(entry.food) lacks text")
            #expect(entry.kind != .blend || !entry.components.isEmpty, "blend \(entry.food) lists no components")
        }
        let ids = guide.entries.map(\.food)
        #expect(Set(ids).count == ids.count, "duplicate entries")
    }

    @Test func coversEveryUnusualSeasoningInTheBundledRecipes() throws {
        let guide = try SpiceGuide.bundled()
        let catalog = try FoodCatalog.bundled()
        var missing: Set<String> = []
        for recipe in try RecipeLibrary.bundled() {
            for ingredient in recipe.ingredients {
                guard let id = ingredient.food, let food = catalog.food(id),
                    food.role == .seasoning || food.group == "herbs-spices"
                else { continue }
                if !Self.everyday.contains(id) && guide.entry(for: id) == nil {
                    missing.insert("\(id) (\(recipe.id))")
                }
            }
        }
        #expect(missing.isEmpty, "no guide entry: \(missing.sorted())")
    }

    @Test func textsUseNoDashes() throws {
        let url = try #require(
            Bundle.module.url(forResource: "spice-guide", withExtension: "json", subdirectory: "Guide"))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(!text.contains("\u{2014}") && !text.contains("\u{2013}"))
    }

    @Test func listsEachEntryOnceInIngredientOrder() throws {
        let dal = try #require(try RecipeLibrary.bundled().first { $0.id == "dal-tadka" })
        let entries = try SpiceGuide.bundled().entries(for: dal).map(\.entry.food)
        #expect(entries.contains("garam-masala"))
        #expect(Set(entries).count == entries.count)
        #expect(entries.contains("asafoetida"))
    }

    @Test func findsEntriesBySpokenName() throws {
        let guide = try SpiceGuide.bundled()
        let catalog = try FoodCatalog.bundled()
        let dal = try #require(try RecipeLibrary.bundled().first { $0.id == "dal-tadka" })
        let session = CookingSession(recipe: dal)
        #expect(guide.entry(named: "masala", in: session, catalog: catalog)?.entry.food == "garam-masala")
        #expect(guide.entry(named: "Hing", in: nil, catalog: catalog)?.entry.food == "asafoetida")
        #expect(guide.entry(named: "Doubanjiang", in: session, catalog: catalog)?.entry.food == "doubanjiang")
        #expect(guide.entry(named: "Salz", in: session, catalog: catalog) == nil)
        #expect(guide.entry(named: "Ahnung", in: session, catalog: catalog) == nil)
    }

    @Test func rejectsNewerSchema() {
        let data = Data(#"{"schemaVersion": 2, "entries": []}"#.utf8)
        #expect(throws: SpiceGuide.LoadError.unsupportedSchemaVersion(2)) { try SpiceGuide.decode(data) }
    }
}
