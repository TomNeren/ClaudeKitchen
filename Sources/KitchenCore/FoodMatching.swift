import Foundation

extension FoodCatalog {
    /// The food an ingredient name most likely means, by the food's name and aliases, or nil when none fits or two
    /// foods fit equally well.
    ///
    /// A name or alias matches when its words appear in a row in the ingredient name, ignoring case and diacritics,
    /// so "Rote Linsen, gewaschen" finds "Rote Linsen". The last word may carry a German plural ending ("Zwiebeln"
    /// finds "Zwiebel"). The part of a food name after a comma is a qualifier and may be left out ("Kichererbsen"
    /// finds "Kichererbsen, gegart"). The match with the most words wins, so "Kokosmilch" never finds "Milch" and
    /// "Rote Linsen" beats "Linsen"; at equal length a full name or alias beats a name without its qualifier, so
    /// "Sojasauce" finds "Sojasauce" and not "Sojasauce, salzreduziert".
    public func food(named name: String) -> FoodID? {
        let words = TextFold.words(name)
        guard !words.isEmpty else { return nil }
        var best: (score: Int, foods: Set<FoodID>) = (0, [])
        for food in foods {
            for (key, isFull) in Self.keys(of: food) where Self.contains(words, key) {
                let score = key.count * 2 + (isFull ? 1 : 0)
                if score > best.score {
                    best = (score, [food.id])
                } else if score == best.score {
                    best.foods.insert(food.id)
                }
            }
        }
        return best.foods.count == 1 ? best.foods.first : nil
    }

    /// The words of the food's name and aliases, each marked as full, and of its name without the qualifier after a
    /// comma.
    private static func keys(of food: Food) -> [(words: [Substring], isFull: Bool)] {
        let full = ([food.name] + food.aliases).map { (TextFold.words($0), true) }
        let short = food.name.contains(",") ? [(TextFold.words(String(food.name.prefix { $0 != "," })), false)] : []
        return (full + short).filter { !$0.0.isEmpty }
    }

    private static let pluralEndings = ["", "n", "en", "e", "s", "er"]

    /// True when `key` occurs as consecutive words in `words`; its last word may carry a plural ending.
    private static func contains(_ words: [Substring], _ key: [Substring]) -> Bool {
        guard key.count <= words.count else { return false }
        for start in 0...(words.count - key.count) {
            let window = words[start..<(start + key.count)]
            let leading = zip(window.dropLast(), key.dropLast()).allSatisfy { $0 == $1 }
            guard leading, let last = window.last, let keyLast = key.last else { continue }
            if pluralEndings.contains(where: { last == keyLast + $0 }) {
                return true
            }
        }
        return false
    }
}

extension Recipe {
    /// The recipe with catalog foods assigned by ingredient name (`FoodCatalog.food(named:)`).
    ///
    /// Ingredients without a food get one when the name matches. With `original`, ingredients that are new or renamed
    /// since then are matched again, so a renamed ingredient does not keep the food of its old name; unchanged
    /// ingredients keep their food, also one a bundled recipe sets by hand.
    public func assigningFoods(from catalog: FoodCatalog, comparedTo original: Recipe? = nil) -> Recipe {
        var recipe = self
        let originalNames = Dictionary(
            (original?.ingredients ?? []).map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        for index in recipe.ingredients.indices {
            let ingredient = recipe.ingredients[index]
            let renamed = original != nil && originalNames[ingredient.id] != ingredient.name
            if ingredient.food == nil || renamed {
                recipe.ingredients[index].food = catalog.food(named: ingredient.name)
            }
        }
        return recipe
    }
}
