import Foundation
import Testing

@testable import KitchenCore

@Suite("Agent brief")
struct AgentBriefTests {
    private static let catalog = FoodCatalog(
        sources: [],
        groups: [FoodGroup(id: "veg", name: "Gemüse", direction: .notAssessed, aisle: .produce)],
        foods: [
            Food(id: "tofu", name: "Tofu, fest", group: "veg", role: .base, searchName: "Tofu natur"),
            Food(id: "pepper", name: "Paprika, rot", group: "veg", role: .base),
            Food(id: "beans", name: "Weiße Bohnen, gegart (Dose)", group: "veg", role: .base),
            Food(id: "cumin", name: "Kreuzkümmel", group: "veg", role: .seasoning),
        ])

    private static func item(
        _ food: FoodID?, _ name: String, _ quantity: ShoppingList.Item.Quantity,
        _ reason: ShoppingList.Item.Reason = .needed
    ) -> ShoppingList.Item {
        .init(food: food, name: name, aisle: .produce, quantity: quantity, reason: reason, recipes: [])
    }

    @Test func searchTermPrefersTheSearchNameElseDropsCommasAndParentheses() throws {
        let foods = Self.catalog.foods
        #expect(foods.map(\.searchTerm) == ["Tofu natur", "Paprika rot", "Weiße Bohnen gegart Dose", "Kreuzkümmel"])
    }

    @Test func searchNameRoundTripsAndIsLeftOutWhenNil() throws {
        let tofu = try #require(Self.catalog.food("tofu"))
        #expect(try JSONDecoder().decode(Food.self, from: JSONEncoder().encode(tofu)) == tofu)
        let pepper = try #require(Self.catalog.food("pepper"))
        let json = String(decoding: try JSONEncoder().encode(pepper), as: UTF8.self)
        #expect(!json.contains("searchName"))
    }

    @Test func itemLinesCarryQuantityAndSearchTerm() {
        let catalog = Self.catalog
        #expect(
            AgentBrief.line(Self.item("tofu", "Tofu, fest", .grams(400, pieces: nil)), catalog: catalog)
                == "- Tofu, fest: mindestens 400 g. Suchbegriff: Tofu natur")
        #expect(
            AgentBrief.line(Self.item("pepper", "Paprika, rot", .grams(300, pieces: 2)), catalog: catalog)
                == "- Paprika, rot: 2 Stk (etwa 300 g). Suchbegriff: Paprika rot")
        #expect(
            AgentBrief.line(Self.item(nil, "Drachenfrucht", .unknown), catalog: catalog)
                == "- Drachenfrucht: kleinste Packung. Suchbegriff: Drachenfrucht")
        #expect(
            AgentBrief.line(Self.item("cumin", "Kreuzkümmel", .level), catalog: catalog)
                == "- Kreuzkümmel: 1 Packung. Suchbegriff: Kreuzkümmel")
    }

    @Test func unknownStockGoesIntoTheAskFirstSection() throws {
        let text = AgentBrief.text(
            for: [
                Self.item("tofu", "Tofu, fest", .grams(400, pieces: nil)),
                Self.item("cumin", "Kreuzkümmel", .level, .unknownStock),
            ], catalog: Self.catalog)
        let buy = try #require(text.range(of: "\nEinkaufen:\n"))
        let ask = try #require(text.range(of: "\nErst fragen (vielleicht noch zu Hause):\n"))
        let tofu = try #require(text.range(of: "- Tofu, fest"))
        let cumin = try #require(text.range(of: "- Kreuzkümmel"))
        #expect(buy.upperBound <= tofu.lowerBound && tofu.upperBound < ask.lowerBound)
        #expect(ask.upperBound <= cumin.lowerBound)
    }

    @Test func theBriefKeepsCheckoutWithTheUserAndStopsAtCaptchas() {
        let text = AgentBrief.text(for: [], catalog: Self.catalog)
        #expect(text.contains("Geh nicht zur Kasse"))
        #expect(text.contains("Löse keine Captchas"))
        #expect(!text.contains("\nEinkaufen:") && !text.contains("\nErst fragen ("))
    }

    @Test func bundledSearchNamesAreSetOnlyWhereTheyDiffer() throws {
        let catalog = try #require(FoodCatalog.shared)
        let redundant = catalog.foods.filter { food in
            guard let searchName = food.searchName else { return false }
            var plain = food
            plain.searchName = nil
            return searchName.isEmpty || searchName == plain.searchTerm
        }
        #expect(redundant.isEmpty, "\(redundant.map(\.id))")
    }
}
