import Foundation

/// Finds the catalog food an ingredient name means. Folds the catalog's names once, so one matcher can serve a whole
/// recipe; build it with `FoodCatalog.matcher`.
public struct FoodMatcher: Sendable {
    private struct Key: Sendable {
        var food: FoodID
        var stems: [Substring]
    }

    private let keys: [Key]

    init(_ catalog: FoodCatalog) {
        keys = catalog.foods.flatMap { food in
            ([food.name] + food.aliases).map { Key(food: food.id, stems: Self.stems($0)) }.filter { !$0.stems.isEmpty }
        }
    }

    /// The food an ingredient name most likely means, by the foods' full names and aliases, or nil when none fits or
    /// two foods fit equally well.
    ///
    /// A name or alias matches when its words appear in a row in the ingredient name, compared by stem: case,
    /// diacritics and common German endings do not count, so "200 g roten Linsen" finds "Rote Linsen" and
    /// "Zwiebeln" finds "Zwiebel". The match with the most words wins, so "Rote Linsen" beats "Linsen", and
    /// "Kokosmilch" never finds "Milch" because words are compared whole. A name with a qualifier after a comma
    /// ("Kichererbsen, gegart") only matches in full; the short form needs an alias, so "Paprika" cannot turn into
    /// "Paprika, rot".
    public func food(named name: String) -> FoodID? {
        let words = Self.stems(name)
        guard !words.isEmpty else { return nil }
        var best: (length: Int, foods: Set<FoodID>) = (0, [])
        for key in keys where key.stems.count >= best.length && Self.contains(words, key.stems) {
            if key.stems.count > best.length {
                best = (key.stems.count, [key.food])
            } else {
                best.foods.insert(key.food)
            }
        }
        return best.foods.count == 1 ? best.foods.first : nil
    }

    private static let endings = ["en", "er", "es", "em", "e", "n", "s"]

    /// Folded words with one common ending removed, as long as at least three letters stay; "ein" stays "ein" and
    /// never meets "Ei".
    private static func stems(_ text: String) -> [Substring] {
        TextFold.words(text).map { word in
            for ending in endings where word.count - ending.count >= 3 && word.hasSuffix(ending) {
                return word.dropLast(ending.count)
            }
            return word
        }
    }

    private static func contains(_ words: [Substring], _ key: [Substring]) -> Bool {
        guard key.count <= words.count else { return false }
        return (0...(words.count - key.count)).contains { start in
            words[start..<(start + key.count)].elementsEqual(key)
        }
    }
}

extension FoodCatalog {
    public var matcher: FoodMatcher { FoodMatcher(self) }

    /// See `FoodMatcher.food(named:)`. Build `matcher` once when matching many names.
    public func food(named name: String) -> FoodID? {
        matcher.food(named: name)
    }
}

extension Recipe {
    /// The recipe with catalog foods assigned by ingredient name (`FoodMatcher.food(named:)`).
    ///
    /// Ingredients without a food get one when the name matches. With `original`, ingredients that are new or renamed
    /// since then are matched again, so a renamed ingredient does not keep the food of its old name; when the new name
    /// matches nothing, the old food stays, because losing it would also lose its boil check. Unchanged ingredients
    /// keep their food, also one a bundled recipe sets by hand. Ingredients with `foodChosenByHand` keep their food
    /// (or none) whatever their name, because the cook chose it.
    public func assigningFoods(from catalog: FoodCatalog, comparedTo original: Recipe? = nil) -> Recipe {
        let matcher = catalog.matcher
        var recipe = self
        let originalNames = Dictionary(
            (original?.ingredients ?? []).map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        for index in recipe.ingredients.indices {
            let ingredient = recipe.ingredients[index]
            guard !ingredient.foodChosenByHand else { continue }
            let renamed = original != nil && originalNames[ingredient.id] != ingredient.name
            guard ingredient.food == nil || renamed else { continue }
            if let food = matcher.food(named: ingredient.name) {
                recipe.ingredients[index].food = food
            }
        }
        return recipe
    }
}
