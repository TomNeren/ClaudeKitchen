import Foundation

public typealias FoodID = Identifier<Food>
public typealias FoodGroupID = Identifier<FoodGroup>

/// What an ingredient does in a dish. The healthy rewrite never swaps or rescales seasonings or aromatics
/// (PLAN.md, decision 26); salt only gets a hint.
public enum FoodRole: String, Sendable, Hashable, Codable, CaseIterable {
    /// Spices, herbs, sauces and acids that define the dish's flavour.
    case seasoning
    /// Onion, garlic, ginger and similar bases that carry the seasoning.
    case aromatic
    /// Main ingredients: grains, legumes, vegetables, meat, fish.
    case base
    case fat
    case liquid
}

/// One food the catalog knows, for example "Rote Linsen".
public struct Food: Sendable, Hashable, Codable, Identifiable {
    public let id: FoodID
    public var name: String
    /// Other names the food goes by, for matching imported ingredient names, for example "Lachsfilet".
    public var aliases: [String]
    public var group: FoodGroupID
    public var role: FoodRole
    /// Weight of one unit, for units that are not grams, for example 100 g per "Stk" onion.
    public var gramsPerUnit: [MeasureUnit: Double]
    /// Nutrients per 100 g, nil for seasonings the source does not list (for example spice blends).
    public var nutrients: Nutrients?

    public init(
        id: FoodID, name: String, aliases: [String] = [], group: FoodGroupID, role: FoodRole,
        gramsPerUnit: [MeasureUnit: Double] = [:], nutrients: Nutrients? = nil
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.group = group
        self.role = role
        self.gramsPerUnit = gramsPerUnit
        self.nutrients = nutrients
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, aliases, group, role, gramsPerUnit, nutrients
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(FoodID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        group = try container.decode(FoodGroupID.self, forKey: .group)
        role = try container.decode(FoodRole.self, forKey: .role)
        gramsPerUnit = try container.decodeIfPresent([MeasureUnit: Double].self, forKey: .gramsPerUnit) ?? [:]
        nutrients = try container.decodeIfPresent(Nutrients.self, forKey: .nutrients)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        if !aliases.isEmpty {
            try container.encode(aliases, forKey: .aliases)
        }
        try container.encode(group, forKey: .group)
        try container.encode(role, forKey: .role)
        if !gramsPerUnit.isEmpty {
            try container.encode(gramsPerUnit, forKey: .gramsPerUnit)
        }
        try container.encodeIfPresent(nutrients, forKey: .nutrients)
    }

    /// The weight of `amount` in grams, nil if it is "to taste" or the unit has no known weight.
    public func grams(of amount: Amount) -> Double? {
        guard case .measured(let value, let unit) = amount else { return nil }
        if unit == .gram { return value }
        return gramsPerUnit[unit].map { value * $0 }
    }
}

extension MeasureUnit: CodingKeyRepresentable {}

/// A group of foods with one health assessment, for example whole grains or processed meat.
///
/// Evidence exists for groups, not for single products, so assessments live here.
public struct FoodGroup: Sendable, Hashable, Codable, Identifiable {
    /// Whether eating more of the group is linked to better or worse health.
    public enum Direction: String, Sendable, Hashable, Codable {
        case favorable
        case neutral
        case limit
        /// Seasonings, water and the like: amounts too small or no evidence on group level.
        case notAssessed
    }

    /// Certainty of the evidence, only set when a source grades it with GRADE or NutriGrade.
    public enum Certainty: String, Sendable, Hashable, Codable {
        case high
        case moderate
        case low
        case veryLow
        case notRated
    }

    public let id: FoodGroupID
    public var name: String
    public var direction: Direction
    public var certainty: Certainty
    /// Sources in the catalog that back `direction`.
    public var sourceIDs: [SourceID]
    /// Measured effects of eating more of the group, each checked against its source.
    public var effects: [EffectEstimate]

    public init(
        id: FoodGroupID, name: String, direction: Direction, certainty: Certainty = .notRated,
        sourceIDs: [SourceID] = [], effects: [EffectEstimate] = []
    ) {
        self.id = id
        self.name = name
        self.direction = direction
        self.certainty = certainty
        self.sourceIDs = sourceIDs
        self.effects = effects
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, direction, certainty, sourceIDs, effects
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(FoodGroupID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        direction = try container.decode(Direction.self, forKey: .direction)
        certainty = try container.decodeIfPresent(Certainty.self, forKey: .certainty) ?? .notRated
        sourceIDs = try container.decodeIfPresent([SourceID].self, forKey: .sourceIDs) ?? []
        effects = try container.decodeIfPresent([EffectEstimate].self, forKey: .effects) ?? []
    }
}

public typealias SourceID = Identifier<EvidenceSource>

/// A publication an assessment cites.
public struct EvidenceSource: Sendable, Hashable, Codable, Identifiable {
    public let id: SourceID
    /// Full citation as it appears in a reference list.
    public var citation: String
    public var year: Int
    public var doi: String?
    public var url: URL?

    public init(id: SourceID, citation: String, year: Int, doi: String? = nil, url: URL? = nil) {
        self.id = id
        self.citation = citation
        self.year = year
        self.doi = doi
        self.url = url
    }
}
