import Foundation

/// Filters recipes by a free-text query and a cuisine.
public enum RecipeSearch {
    /// Recipes of `cuisine` (any cuisine when nil) whose name, tag, cuisine name, region or any ingredient contains
    /// every word of `query`, ignoring case and diacritics. `cuisineName` lets the app search its own wording,
    /// for example "Indien". An empty query and no cuisine return all recipes in their original order.
    public static func filter(
        _ recipes: [Recipe], query: String, cuisine: Cuisine? = nil,
        cuisineName: (Cuisine) -> String = \.rawValue
    ) -> [Recipe] {
        let words = query.split(whereSeparator: \.isWhitespace).map { normalized(String($0)) }
        return recipes.filter { recipe in
            if let cuisine, recipe.origin?.cuisine != cuisine { return false }
            guard !words.isEmpty else { return true }
            let haystack = normalized(
                ([
                    recipe.name, recipe.tag, recipe.origin.map { cuisineName($0.cuisine) } ?? "",
                    recipe.origin?.region ?? "",
                ]
                    + recipe.ingredients.map(\.name))
                    .joined(separator: " "))
            return words.allSatisfy { haystack.contains($0) }
        }
    }

    /// The cuisines that occur in `recipes`, in the order of `Cuisine.allCases`, for a filter menu.
    public static func cuisines(in recipes: [Recipe]) -> [Cuisine] {
        let present = Set(recipes.compactMap(\.origin?.cuisine))
        return Cuisine.allCases.filter(present.contains)
    }

    /// Folds case and diacritics. The Turkish dotless ı has no base letter to fold to, so it becomes i by hand.
    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).replacing("ı", with: "i")
    }
}
