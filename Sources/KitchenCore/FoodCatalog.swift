import Foundation

/// Foods, food groups with their health assessment, and the sources behind them.
///
/// Ships as `Resources/Evidence/food-catalog.json`. Recipes point at foods through `Ingredient.food`.
public struct FoodCatalog: Sendable, Hashable, Codable {
    /// The JSON schema version this type reads and writes.
    public static let currentSchemaVersion = 1

    public enum LoadError: Error, Equatable {
        case missingResource
        case unsupportedSchemaVersion(Int)
    }

    public var schemaVersion: Int
    public var sources: [EvidenceSource]
    public var groups: [FoodGroup]
    public var foods: [Food]

    public init(
        sources: [EvidenceSource], groups: [FoodGroup], foods: [Food],
        schemaVersion: Int = FoodCatalog.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.sources = sources
        self.groups = groups
        self.foods = foods
    }

    /// The catalog that ships with the app.
    public static func bundled() throws -> FoodCatalog {
        guard
            let url = Bundle.module.url(
                forResource: "food-catalog", withExtension: "json", subdirectory: "Evidence")
        else {
            throw LoadError.missingResource
        }
        return try decode(Data(contentsOf: url))
    }

    public static func decode(_ data: Data) throws -> FoodCatalog {
        let catalog = try JSONDecoder().decode(FoodCatalog.self, from: data)
        guard catalog.schemaVersion <= currentSchemaVersion else {
            throw LoadError.unsupportedSchemaVersion(catalog.schemaVersion)
        }
        return catalog
    }

    public func food(_ id: FoodID) -> Food? {
        foods.first { $0.id == id }
    }

    public func group(_ id: FoodGroupID) -> FoodGroup? {
        groups.first { $0.id == id }
    }

    public func source(_ id: SourceID) -> EvidenceSource? {
        sources.first { $0.id == id }
    }

    /// The catalog food an ingredient points at, nil if it has none or the ID is unknown.
    public func food(for ingredient: Ingredient) -> Food? {
        ingredient.food.flatMap(food)
    }
}

/// Something `FoodCatalog.issues()` or `issues(in:)` found.
public enum CatalogIssue: Sendable, Hashable {
    case duplicateSource(SourceID)
    case duplicateGroup(FoodGroupID)
    case duplicateFood(FoodID)
    case unknownSource(group: FoodGroupID, source: SourceID)
    case unknownGroup(food: FoodID, group: FoodGroupID)
    /// A weight per unit that is not a positive number, or a weight given for grams.
    case invalidWeight(food: FoodID, unit: MeasureUnit)
    /// A group says more or less is better, but cites nothing.
    case assessedWithoutSource(FoodGroupID)
    case unmappedIngredient(IngredientID)
    case unknownFood(ingredient: IngredientID, food: FoodID)
    /// The ingredient is measured in a unit the food has no weight for, so it cannot be counted in grams.
    case missingWeight(ingredient: IngredientID, unit: MeasureUnit)
}

extension FoodCatalog {
    /// Problems inside the catalog itself. Empty for a consistent catalog.
    public func issues() -> [CatalogIssue] {
        var issues: [CatalogIssue] = []
        issues += duplicates(sources.map(\.id)).map(CatalogIssue.duplicateSource)
        issues += duplicates(groups.map(\.id)).map(CatalogIssue.duplicateGroup)
        issues += duplicates(foods.map(\.id)).map(CatalogIssue.duplicateFood)
        let sourceIDs = Set(sources.map(\.id))
        for group in groups {
            for source in group.sourceIDs where !sourceIDs.contains(source) {
                issues.append(.unknownSource(group: group.id, source: source))
            }
            if group.direction != .notAssessed && group.sourceIDs.isEmpty {
                issues.append(.assessedWithoutSource(group.id))
            }
        }
        let groupIDs = Set(groups.map(\.id))
        for food in foods {
            if !groupIDs.contains(food.group) {
                issues.append(.unknownGroup(food: food.id, group: food.group))
            }
            for (unit, grams) in food.gramsPerUnit.sorted(by: { $0.key.rawValue < $1.key.rawValue })
            where unit == .gram || !grams.isFinite || grams <= 0 {
                issues.append(.invalidWeight(food: food.id, unit: unit))
            }
        }
        return issues
    }

    /// Ingredients of `recipe` that are not mapped to a known food or cannot be weighed.
    public func issues(in recipe: Recipe) -> [CatalogIssue] {
        recipe.ingredients.compactMap { ingredient in
            guard let foodID = ingredient.food else { return .unmappedIngredient(ingredient.id) }
            guard let food = food(foodID) else { return .unknownFood(ingredient: ingredient.id, food: foodID) }
            if case .measured(_, let unit) = ingredient.amount, unit != .gram, food.gramsPerUnit[unit] == nil {
                return .missingWeight(ingredient: ingredient.id, unit: unit)
            }
            return nil
        }
    }
}

private func duplicates<ID: Hashable>(_ ids: [ID]) -> [ID] {
    var seen: Set<ID> = []
    var reported: Set<ID> = []
    return ids.filter { id in
        if seen.insert(id).inserted { return false }
        return reported.insert(id).inserted
    }
}
