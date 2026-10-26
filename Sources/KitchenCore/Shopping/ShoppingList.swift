import Foundation

/// What to buy for a set of planned recipes, sorted by aisle.
public struct ShoppingList: Sendable, Hashable {
    public struct Item: Sendable, Hashable {
        public enum Quantity: Sendable, Hashable {
            /// Grams to buy, rounded up to a shopping step, and the same in pieces when the food has a piece weight.
            case grams(Double, pieces: Int?)
            /// A seasoning: buy one pack.
            case level
            /// The recipe says "to taste" or uses a unit the catalog cannot weigh.
            case unknown
        }

        public enum Reason: Sendable, Hashable {
            /// A planned recipe needs more than is at home.
            case needed
            /// After the planned recipes the stock would fall below its minimum, or already has.
            case belowMinimum
            /// A seasoning the pantry has as `low`, needed by a planned recipe.
            case runningLow
            /// A seasoning a planned recipe needs that the pantry does not list: check the cupboard.
            case unknownStock
        }

        /// Nil for ingredients the catalog does not know.
        public var food: FoodID?
        public var name: String
        public var aisle: Aisle
        public var quantity: Quantity
        public var reason: Reason
        /// The planned recipes that need it, empty for a pure restock.
        public var recipes: [RecipeID]
    }

    public var items: [Item]

    /// The list for `plans` (recipe and servings) given what is in `pantry`.
    ///
    /// Gram foods: what the plans need minus the stock, topped up to the minimum if one is set; empty stock counts
    /// as zero. Seasonings: listed when `empty` or not in the pantry, and when `low` if a plan needs them. Pantry
    /// foods below their minimum or empty are listed even when no plan needs them. Water is never listed.
    /// Ingredients without a food are listed by name with their quantity unknown.
    public init(plans: [(recipe: Recipe, servings: Int)], pantry: Pantry, catalog: FoodCatalog) {
        var demand = Demand()
        for plan in plans {
            demand.add(plan.recipe, servings: plan.servings, catalog: catalog)
        }
        var items: [Item] = []
        var handled: Set<FoodID> = []
        for (foodID, need) in demand.foods {
            handled.insert(foodID)
            guard let food = catalog.food(foodID),
                let item = Self.item(for: food, need: need, pantry: pantry[foodID], catalog: catalog)
            else { continue }
            items.append(item)
        }
        for stock in pantry.items where !handled.contains(stock.food) {
            guard let food = catalog.food(stock.food),
                let item = Self.restock(food, stock: stock, catalog: catalog)
            else { continue }
            items.append(item)
        }
        for (name, recipes) in demand.unknown {
            items.append(
                Item(food: nil, name: name, aisle: .other, quantity: .unknown, reason: .needed, recipes: recipes))
        }
        self.items = items.sorted { ($0.aisle, $0.name) < ($1.aisle, $1.name) }
    }

    private static func item(for food: Food, need: Demand.Need, pantry: PantryItem?, catalog: FoodCatalog) -> Item? {
        let aisle = catalog.aisle(of: food)
        func item(_ quantity: Item.Quantity, _ reason: Item.Reason) -> Item {
            Item(
                food: food.id, name: food.name, aisle: aisle, quantity: quantity, reason: reason, recipes: need.recipes)
        }
        if catalog.tracksLevel(food) {
            switch pantry?.stock {
            case .level(.available)?: return nil
            case .level(.low)?: return item(.level, .runningLow)
            case .level(.empty)?: return item(.level, .needed)
            case .grams(let grams)? where grams > 0: return nil
            default: return item(.level, pantry == nil ? .unknownStock : .needed)
            }
        }
        guard need.weighable else { return item(.unknown, .needed) }
        let stock: Double
        if case .grams(let grams)? = pantry?.stock {
            stock = grams
        } else {
            stock = 0
        }
        let missing = max(0, need.grams - stock)
        let minimum = pantry?.minimumGrams ?? 0
        let topUp = max(missing, minimum - (stock - need.grams))
        guard topUp > 0 else { return nil }
        return item(quantity(grams: topUp, of: food), missing > 0 ? .needed : .belowMinimum)
    }

    private static func restock(_ food: Food, stock: PantryItem, catalog: FoodCatalog) -> Item? {
        let quantity: Item.Quantity
        switch stock.stock {
        case .level(.empty):
            quantity = .level
        case .grams(let grams):
            guard let minimum = stock.minimumGrams, grams < minimum else { return nil }
            quantity = Self.quantity(grams: minimum - grams, of: food)
        default:
            return nil
        }
        return Item(
            food: food.id, name: food.name, aisle: catalog.aisle(of: food), quantity: quantity, reason: .belowMinimum,
            recipes: [])
    }

    /// Rounds up to 10 g below 100 g, to 50 g below 1 kg, else to 100 g; pieces round up on their own.
    static func quantity(grams: Double, of food: Food) -> Item.Quantity {
        let step: Double = grams <= 100 ? 10 : grams <= 1000 ? 50 : 100
        let rounded = (grams / step).rounded(.up) * step
        let pieces = food.gramsPerUnit[.piece].map { Int((grams / $0).rounded(.up)) }
        return .grams(rounded, pieces: pieces)
    }
}

/// What a set of recipes uses, per food.
struct Demand {
    struct Need {
        var grams: Double = 0
        /// False when one of the uses is "to taste" or cannot be weighed.
        var weighable = true
        var recipes: [RecipeID] = []
    }

    private(set) var foods: [FoodID: Need] = [:]
    /// Ingredients without a known food, by name, with the recipes that use them.
    private(set) var unknown: [String: [RecipeID]] = [:]

    mutating func add(_ recipe: Recipe, servings: Int, catalog: FoodCatalog) {
        for ingredient in recipe.ingredients {
            guard let food = catalog.food(for: ingredient) else {
                unknown[ingredient.name, default: []].appendOnce(recipe.id)
                continue
            }
            guard food.id != Food.water else { continue }
            let amount = ingredient.amount(from: recipe.baseServings, to: servings)
            var need = foods[food.id] ?? Need()
            if let grams = food.grams(of: amount) {
                need.grams += grams
            } else {
                need.weighable = false
            }
            need.recipes.appendOnce(recipe.id)
            foods[food.id] = need
        }
    }

    /// Grams per food that `recipe` uses for `servings`; uses that cannot be weighed are left out.
    static func grams(of recipe: Recipe, servings: Int, catalog: FoodCatalog) -> [FoodID: Double] {
        var demand = Demand()
        demand.add(recipe, servings: servings, catalog: catalog)
        return demand.foods.mapValues(\.grams)
    }
}

extension Array where Element: Equatable {
    fileprivate mutating func appendOnce(_ element: Element) {
        if !contains(element) {
            append(element)
        }
    }
}
