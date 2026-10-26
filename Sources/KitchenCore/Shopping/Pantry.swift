import Foundation

/// How much of a seasoning is left, without weighing it.
public enum SupplyLevel: String, Sendable, Hashable, Codable, CaseIterable {
    case available
    case low
    case empty
}

/// What is at home of one food.
public struct PantryItem: Sendable, Hashable, Codable {
    public enum Stock: Sendable, Hashable, Codable {
        case grams(Double)
        case level(SupplyLevel)
    }

    public var food: FoodID
    public var stock: Stock
    /// For basics like rice or oil: the shopping list tops the stock up to this many grams.
    public var minimumGrams: Double?

    public init(food: FoodID, stock: Stock, minimumGrams: Double? = nil) {
        self.food = food
        self.stock = stock
        self.minimumGrams = minimumGrams
    }
}

/// Everything at home, one item per food.
public struct Pantry: Sendable, Hashable, Codable {
    public private(set) var items: [PantryItem]

    public init(items: [PantryItem] = []) {
        self.items = []
        for item in items {
            self[item.food] = item
        }
    }

    public subscript(food: FoodID) -> PantryItem? {
        get { items.first { $0.food == food } }
        set {
            items.removeAll { $0.food == food }
            if var item = newValue {
                item.food = food
                items.append(item)
            }
        }
    }

    /// The pantry after cooking `recipe` for `servings`: grams of every tracked food go down by what the recipe
    /// uses, never below zero. Levels stay, because nobody knows how much of a spice jar a teaspoon is. Foods that
    /// are not in the pantry stay out. Keep the old value to undo.
    public func cooking(_ recipe: Recipe, servings: Int, catalog: FoodCatalog) -> Pantry {
        var pantry = self
        for (food, grams) in Demand.grams(of: recipe, servings: servings, catalog: catalog) {
            guard case .grams(let stock)? = pantry[food]?.stock else { continue }
            pantry[food]?.stock = .grams(max(0, stock - grams))
        }
        return pantry
    }

    /// The pantry after buying `list`: grams are added, bought seasonings are `available` again. Bought foods that
    /// were not in the pantry are added, so the next list knows them.
    public func buying(_ list: ShoppingList) -> Pantry {
        var pantry = self
        for item in list.items {
            guard let food = item.food else { continue }
            switch item.quantity {
            case .grams(let grams, _):
                let stock: Double
                if case .grams(let current)? = pantry[food]?.stock {
                    stock = current
                } else {
                    stock = 0
                }
                let minimum = pantry[food]?.minimumGrams
                pantry[food] = PantryItem(food: food, stock: .grams(stock + grams), minimumGrams: minimum)
            case .level:
                pantry[food] = PantryItem(food: food, stock: .level(.available))
            case .unknown:
                continue
            }
        }
        return pantry
    }
}
