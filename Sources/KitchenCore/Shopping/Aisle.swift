import Foundation

/// A part of the supermarket, in the order the shopping list walks through it.
public enum Aisle: String, Sendable, Hashable, Codable, CaseIterable, Comparable {
    case produce
    case chilled
    case frozen
    case dryGoods
    case spices
    /// Ingredients the catalog does not know.
    case other

    public static func < (lhs: Aisle, rhs: Aisle) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

extension FoodCatalog {
    /// The food's own aisle, else its group's, else `.other`.
    public func aisle(of food: Food) -> Aisle {
        food.aisle ?? groups.first { $0.id == food.group }?.aisle ?? .other
    }

    /// True for foods kept as "da, fast leer, leer" instead of in grams: seasonings and sauces that last for many
    /// recipes. Fresh herbs are seasonings too but are bought per recipe, so they count in grams.
    public func tracksLevel(_ food: Food) -> Bool {
        food.role == .seasoning && aisle(of: food) != .produce
    }
}
