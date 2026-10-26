import Foundation

/// How much of a seasoning is left, without weighing it.
public enum SupplyLevel: String, Sendable, Hashable, Codable, CaseIterable {
    case available
    case low
    case empty
}

/// What is at home of one food.
public struct PantryItem: Sendable, Hashable, Codable {
    /// Stored as `{"grams": 500}` or `{"level": "low"}`.
    public enum Stock: Sendable, Hashable, Codable {
        case grams(Double)
        case level(SupplyLevel)

        private enum CodingKeys: String, CodingKey {
            case grams, level
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let grams = try container.decodeIfPresent(Double.self, forKey: .grams) {
                self = .grams(grams)
            } else {
                self = .level(try container.decode(SupplyLevel.self, forKey: .level))
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .grams(let grams): try container.encode(grams, forKey: .grams)
            case .level(let level): try container.encode(level, forKey: .level)
            }
        }
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
    private var byFood: [FoodID: PantryItem]

    public init(items: [PantryItem] = []) {
        byFood = Dictionary(items.map { ($0.food, $0) }, uniquingKeysWith: { _, last in last })
    }

    /// The items sorted by food id, so equal pantries list and store them the same way.
    public var items: [PantryItem] {
        byFood.values.sorted { $0.food.rawValue < $1.food.rawValue }
    }

    public subscript(food: FoodID) -> PantryItem? {
        get { byFood[food] }
        set {
            var item = newValue
            item?.food = food
            byFood[food] = item
        }
    }

    /// Stored as a plain list; a food listed twice keeps its last entry.
    public init(from decoder: any Decoder) throws {
        self.init(items: try decoder.singleValueContainer().decode([PantryItem].self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(items)
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

    /// The pantry after buying `list`: grams are added, bought seasonings are `available` again. An item keeps the
    /// kind it was stored with. Bought foods that were not in the pantry are added, so the next list knows them.
    public func buying(_ list: ShoppingList) -> Pantry {
        var pantry = self
        for item in list.items {
            guard let food = item.food else { continue }
            switch (item.quantity, pantry[food]?.stock) {
            case (.unknown, _):
                continue
            case (_, .level?), (.level, nil):
                pantry[food] = PantryItem(food: food, stock: .level(.available))
            case (.grams(let grams, _), .grams(let current)?):
                pantry[food]?.stock = .grams(current + grams)
            case (.grams(let grams, _), nil):
                pantry[food] = PantryItem(food: food, stock: .grams(grams))
            case (.level, .grams?):
                continue
            }
        }
        return pantry
    }
}
