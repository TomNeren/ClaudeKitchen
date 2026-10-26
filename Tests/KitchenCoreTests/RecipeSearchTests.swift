import Foundation
import Testing

@testable import KitchenCore

@Suite("Recipe search")
struct RecipeSearchTests {
    private let recipes: [Recipe]

    init() throws {
        recipes = try RecipeLibrary.bundled()
    }

    private func ids(_ query: String) -> [String] {
        RecipeSearch.filter(recipes, query: query).map(\.id.rawValue)
    }

    @Test func emptyQueryReturnsEverything() {
        #expect(ids("  ") == recipes.map(\.id.rawValue))
    }

    @Test func matchesNameTagAndIngredientsIgnoringCaseAndDiacritics() {
        #expect(Set(ids("LINSEN")) == ["zitronen-linsen-eintopf", "mercimek-corbasi", "mujaddara"])
        #expect(ids("mercimek corbasi") == ["mercimek-corbasi"])
        #expect(ids("ÇORBASI") == ["mercimek-corbasi"])
        #expect(Set(ids("dampf")) == ["ingwer-lachs-pak-choi", "gedaempfter-wolfsbarsch"])
        #expect(
            Set(ids("kokosmilch")) == [
                "kichererbsen-spinat-curry", "gaeng-keow-wan-gai", "tom-kha-gai", "sayur-lodeh",
            ])
        #expect(Set(ids("gemusebruhe")) == ["zitronen-linsen-eintopf", "borschtsch"])
    }

    @Test func everyWordMustMatch() {
        #expect(ids("ingwer lachs") == ["ingwer-lachs-pak-choi"])
        let ginger = ids("ingwer")
        #expect(ginger.contains("ingwer-lachs-pak-choi") && ginger.contains("kichererbsen-spinat-curry"))
        #expect(!ginger.contains("zitronen-linsen-eintopf") && !ginger.contains("jeera-reis"))
        #expect(ids("ingwer feta").isEmpty)
    }
}

@Suite("Recipe origin")
struct RecipeOriginTests {
    private static func recipe(_ id: RecipeID, _ name: String, _ origin: RecipeOrigin?) -> Recipe {
        Recipe(
            id: id, name: name, tag: "", baseServings: 2, totalMinutes: 10, ingredients: [], steps: [],
            origin: origin)
    }

    private static let recipes = [
        recipe("dal", "Dal Makhani", RecipeOrigin(cuisine: .india, region: "Punjab")),
        recipe("lobio", "Lobio", RecipeOrigin(cuisine: .georgia)),
        recipe("own", "Eigenes Linsengericht", nil),
        recipe("chana", "Chana Masala", RecipeOrigin(cuisine: .india)),
    ]

    @Test func filtersByCuisineAndQueryTogether() {
        #expect(RecipeSearch.filter(Self.recipes, query: "", cuisine: .india).map(\.id) == ["dal", "chana"])
        #expect(RecipeSearch.filter(Self.recipes, query: "chana", cuisine: .india).map(\.id) == ["chana"])
        #expect(RecipeSearch.filter(Self.recipes, query: "lobio", cuisine: .india).isEmpty)
        #expect(RecipeSearch.filter(Self.recipes, query: "", cuisine: .china).isEmpty)
    }

    @Test func foldsLettersWithoutABaseLetter() {
        let recipes = [Self.recipe("golabki", "Gołąbki", nil), Self.recipe("strudel", "Straßenstrudel", nil)]
        #expect(RecipeSearch.filter(recipes, query: "golabki").map(\.id) == ["golabki"])
        #expect(RecipeSearch.filter(recipes, query: "STRASSEN").map(\.id) == ["strudel"])
    }

    @Test func queryMatchesRegionAndCuisineName() {
        #expect(RecipeSearch.filter(Self.recipes, query: "punjab").map(\.id) == ["dal"])
        #expect(RecipeSearch.filter(Self.recipes, query: "georgia").map(\.id) == ["lobio"])
        let german = RecipeSearch.filter(Self.recipes, query: "indien") { $0 == .india ? "Indien" : "" }
        #expect(german.map(\.id) == ["dal", "chana"])
    }

    @Test func listsTheCuisinesPresentInCanonicalOrder() {
        #expect(RecipeSearch.cuisines(in: Self.recipes) == [.india, .georgia])
    }

    @Test func copyKeepsOriginReferencesAndChecks() {
        var original = Self.recipes[0]
        original.references = [RecipeReference(title: "Werk")]
        original.authenticityChecks = ["Butter und Sahne gehören dazu"]
        let copy = original.copy(id: "mein-dal", name: "Mein Dal")
        #expect(copy.origin == original.origin)
        #expect(copy.references == original.references && copy.authenticityChecks == original.authenticityChecks)
    }

    /// The hand-written Codable lists every stored property; a new one must be added there too.
    @Test func codableCoversEveryStoredProperty() throws {
        let labels = Mirror(reflecting: Self.recipes[0]).children.compactMap(\.label)
        #expect(
            labels == [
                "id", "name", "tag", "baseServings", "totalMinutes", "ingredients", "steps", "verified", "variantOf",
                "origin", "references", "authenticityChecks", "schemaVersion",
            ])
        var full = Self.recipes[0]
        full.variantOf = "x"
        full.references = [RecipeReference(title: "T", author: "A", year: 1, url: URL(string: "https://example.org"))]
        full.authenticityChecks = ["c"]
        #expect(try RecipeLibrary.decode(JSONEncoder().encode(full)) == full)
    }

    @Test func decodesOriginReferencesAndChecks() throws {
        let json = """
            {"schemaVersion": 1, "id": "x", "name": "X", "tag": "", "baseServings": 2, "totalMinutes": 10,
             "verified": false, "ingredients": [], "steps": [],
             "origin": {"cuisine": "georgia", "region": "Imeretien"},
             "references": [{"title": "Standardwerk", "author": "A. Autorin", "year": 2001}],
             "authenticityChecks": ["Gewürze: Utskho Suneli, Koriander"]}
            """
        let recipe = try RecipeLibrary.decode(Data(json.utf8))
        #expect(recipe.origin == RecipeOrigin(cuisine: .georgia, region: "Imeretien"))
        #expect(recipe.references == [RecipeReference(title: "Standardwerk", author: "A. Autorin", year: 2001)])
        #expect(recipe.authenticityChecks == ["Gewürze: Utskho Suneli, Koriander"])
        #expect(try RecipeLibrary.decode(JSONEncoder().encode(recipe)) == recipe)
    }

    @Test func recipeWithoutTheNewKeysStillDecodes() throws {
        let json = """
            {"schemaVersion": 1, "id": "x", "name": "X", "tag": "", "baseServings": 2, "totalMinutes": 10,
             "verified": false, "ingredients": [], "steps": []}
            """
        let recipe = try RecipeLibrary.decode(Data(json.utf8))
        #expect(recipe.origin == nil && recipe.references.isEmpty && recipe.authenticityChecks.isEmpty)
    }
}
