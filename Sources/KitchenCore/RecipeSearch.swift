import Foundation

/// Filters recipes by a free-text query.
public enum RecipeSearch {
    /// Recipes whose name, tag or any ingredient contains every word of `query`, ignoring case and diacritics.
    /// An empty query returns all recipes in their original order.
    public static func filter(_ recipes: [Recipe], query: String) -> [Recipe] {
        let words = query.split(whereSeparator: \.isWhitespace).map { normalized(String($0)) }
        guard !words.isEmpty else { return recipes }
        return recipes.filter { recipe in
            let haystack = normalized(
                ([recipe.name, recipe.tag] + recipe.ingredients.map(\.name)).joined(separator: " "))
            return words.allSatisfy { haystack.contains($0) }
        }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
