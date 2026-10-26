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
        #expect(ids("LINSEN") == ["zitronen-linsen-eintopf"])
        #expect(ids("dampf") == ["ingwer-lachs-pak-choi"])
        #expect(ids("kokosmilch") == ["kichererbsen-spinat-curry"])
        #expect(ids("gemusebruhe") == ["zitronen-linsen-eintopf"])
    }

    @Test func everyWordMustMatch() {
        #expect(ids("ingwer lachs") == ["ingwer-lachs-pak-choi"])
        #expect(ids("ingwer").sorted() == ["ingwer-lachs-pak-choi", "kichererbsen-spinat-curry"])
        #expect(ids("ingwer feta").isEmpty)
    }
}

@Suite("Recipe origin")
struct RecipeOriginTests {
    @Test func filtersByCuisineAndQueryTogether() throws {
        let recipes = try RecipeLibrary.bundled()
        #expect(RecipeSearch.filter(recipes, query: "", cuisine: .india).map(\.id) == ["kichererbsen-spinat-curry"])
        #expect(RecipeSearch.filter(recipes, query: "linsen", cuisine: .india).isEmpty)
        #expect(RecipeSearch.filter(recipes, query: "ikaria").map(\.id) == ["zitronen-linsen-eintopf"])
        #expect(RecipeSearch.filter(recipes, query: "", cuisine: .georgia).isEmpty)
    }

    @Test func listsTheCuisinesPresentInCanonicalOrder() throws {
        #expect(RecipeSearch.cuisines(in: try RecipeLibrary.bundled()) == [.india, .europe])
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
