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
