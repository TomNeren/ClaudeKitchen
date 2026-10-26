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
    public var targets: [IntakeTarget]

    public init(
        sources: [EvidenceSource], groups: [FoodGroup], foods: [Food], targets: [IntakeTarget] = [],
        schemaVersion: Int = FoodCatalog.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.sources = sources
        self.groups = groups
        self.foods = foods
        self.targets = targets
    }

    /// The bundled catalog, loaded once; nil if it cannot be read. Default weigher for `DeviceProfile`'s fill check.
    public static let shared: FoodCatalog? = try? bundled()

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

    /// Decodes a catalog, checking the schema version before the rest so a newer file fails with
    /// `unsupportedSchemaVersion` instead of a missing key.
    public static func decode(_ data: Data) throws -> FoodCatalog {
        struct Header: Decodable { var schemaVersion: Int }
        let version = try JSONDecoder().decode(Header.self, from: data).schemaVersion
        guard version <= currentSchemaVersion else {
            throw LoadError.unsupportedSchemaVersion(version)
        }
        return try JSONDecoder().decode(FoodCatalog.self, from: data)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, sources, groups, foods, targets
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        sources = try container.decode([EvidenceSource].self, forKey: .sources)
        groups = try container.decode([FoodGroup].self, forKey: .groups)
        foods = try container.decode([Food].self, forKey: .foods)
        targets = try container.decodeIfPresent([IntakeTarget].self, forKey: .targets) ?? []
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
    /// A food has no nutrients and is not marked `nutrientsUnavailable`, so recipe totals would silently leave it out.
    case missingNutrients(FoodID)
    /// Negative values, more saturated fat than fat, or more than 100 g of macronutrients per 100 g.
    case implausibleNutrients(FoodID)
    /// `lowSodiumVersionOf` names an unknown food, one of another group, role or unit weights, or one without more
    /// sodium.
    case invalidLowSodiumVersion(FoodID)
    /// The effect's source is not among the sources its group cites.
    case uncitedEffectSource(group: FoodGroupID, source: SourceID)
    /// The relative risk is not positive, lies outside its interval, or the quote is missing.
    case invalidEffect(FoodGroupID)
    /// A clear effect points another way than the group's direction, for example a favorable group with RR above 1,
    /// or a neutral group with a clear effect either way.
    case effectContradictsDirection(FoodGroupID)
    case duplicateTarget(IntakeTargetID)
    case unknownTargetGroup(target: IntakeTargetID, group: FoodGroupID)
    case unknownTargetSource(target: IntakeTargetID, source: SourceID)
    /// No bound, a bound that is not positive, a minimum above the maximum, or a missing quote.
    case invalidTarget(IntakeTargetID)
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
            for effect in group.effects {
                if !group.sourceIDs.contains(effect.sourceID) {
                    issues.append(.uncitedEffectSource(group: group.id, source: effect.sourceID))
                }
                if !effect.isValid {
                    issues.append(.invalidEffect(group.id))
                } else if effect.contradicts(group.direction) {
                    issues.append(.effectContradictsDirection(group.id))
                }
            }
        }
        let groupIDs = Set(groups.map(\.id))
        issues += duplicates(targets.map(\.id)).map(CatalogIssue.duplicateTarget)
        for target in targets {
            for group in target.groups where !groupIDs.contains(group) {
                issues.append(.unknownTargetGroup(target: target.id, group: group))
            }
            if !sourceIDs.contains(target.sourceID) {
                issues.append(.unknownTargetSource(target: target.id, source: target.sourceID))
            }
            if !target.isValid {
                issues.append(.invalidTarget(target.id))
            }
        }
        for food in foods {
            if !groupIDs.contains(food.group) {
                issues.append(.unknownGroup(food: food.id, group: food.group))
            }
            for (unit, grams) in food.gramsPerUnit.sorted(by: { $0.key.rawValue < $1.key.rawValue })
            where unit == .gram || !grams.isFinite || grams <= 0 {
                issues.append(.invalidWeight(food: food.id, unit: unit))
            }
            if let nutrients = food.nutrients {
                if !nutrients.isPlausible {
                    issues.append(.implausibleNutrients(food.id))
                }
            } else if !food.nutrientsUnavailable {
                issues.append(.missingNutrients(food.id))
            }
            if let originalID = food.lowSodiumVersionOf {
                let original = self.food(originalID)
                let isValid =
                    original.map { original in
                        original.group == food.group && original.role == food.role
                            && original.gramsPerUnit == food.gramsPerUnit
                            && (food.nutrients?.sodiumMilligrams ?? .infinity)
                                < (original.nutrients?.sodiumMilligrams ?? 0)
                    } ?? false
                if !isValid {
                    issues.append(.invalidLowSodiumVersion(food.id))
                }
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

extension EffectEstimate {
    fileprivate var isValid: Bool {
        lower > 0 && lower <= relativeRisk && relativeRisk <= upper && servingGrams.map { $0 > 0 } != false
            && !quote.isEmpty
    }

    fileprivate func contradicts(_ direction: FoodGroup.Direction) -> Bool {
        guard isSignificant else { return false }
        switch direction {
        case .favorable: return relativeRisk > 1
        case .limit: return relativeRisk < 1
        case .neutral, .notAssessed: return true
        }
    }
}

extension IntakeTarget {
    fileprivate var isValid: Bool {
        let bounds = [minimum, maximum].compactMap { $0 }
        guard !bounds.isEmpty, bounds.allSatisfy({ $0 > 0 }), !quote.isEmpty, !groups.isEmpty else { return false }
        if let minimum, let maximum, minimum > maximum { return false }
        // A serving size only means something for targets counted in servings.
        guard let servingGrams else { return true }
        return measure == .servings && servingGrams > 0
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
