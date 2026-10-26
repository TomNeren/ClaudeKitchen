import Foundation

public typealias RewriteGoalID = Identifier<RewriteGoal>
public typealias SwapRuleID = Identifier<SwapRule>

/// Swaps one food for a healthier one, wholly or in part.
///
/// JSON shape: `{"id": "brown-rice", "from": "white-rice", "to": "brown-rice", "toName": "Vollkornreis",
/// "share": 1, "ratio": 1, "extraSeconds": 900, "stepNote": "…", "sourceID": "dge-2024", "quote": "…"}`.
/// `share` and `ratio` default to 1, `extraSeconds` to 0.
public struct SwapRule: Sendable, Hashable, Codable, Identifiable {
    public let id: SwapRuleID
    public var from: FoodID
    public var to: FoodID
    /// Ingredient name the swapped food gets in the recipe.
    public var toName: String
    /// Part of the original amount that is swapped, in (0, 1]. 0.5 keeps half the original.
    public var share: Double
    /// Amount of the new food per unit of the swapped part, for example 0.8 g oil per g butter.
    public var ratio: Double
    /// Extra cooking time for steps that cook the swapped food.
    public var extraTime: Duration
    /// Note added to every step that uses the swapped food.
    public var stepNote: String?
    public var sourceID: SourceID
    /// The passage of the source that backs the swap, verbatim.
    public var quote: String

    public init(
        id: SwapRuleID, from: FoodID, to: FoodID, toName: String, share: Double = 1, ratio: Double = 1,
        extraTime: Duration = .zero, stepNote: String? = nil, sourceID: SourceID, quote: String
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.toName = toName
        self.share = share
        self.ratio = ratio
        self.extraTime = extraTime
        self.stepNote = stepNote
        self.sourceID = sourceID
        self.quote = quote
    }

    private enum CodingKeys: String, CodingKey {
        case id, from, to, toName, share, ratio, extraSeconds, stepNote, sourceID, quote
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(SwapRuleID.self, forKey: .id)
        from = try container.decode(FoodID.self, forKey: .from)
        to = try container.decode(FoodID.self, forKey: .to)
        toName = try container.decode(String.self, forKey: .toName)
        share = try container.decodeIfPresent(Double.self, forKey: .share) ?? 1
        ratio = try container.decodeIfPresent(Double.self, forKey: .ratio) ?? 1
        extraTime = .seconds(try container.decodeIfPresent(Int.self, forKey: .extraSeconds) ?? 0)
        stepNote = try container.decodeIfPresent(String.self, forKey: .stepNote)
        sourceID = try container.decode(SourceID.self, forKey: .sourceID)
        quote = try container.decode(String.self, forKey: .quote)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encode(toName, forKey: .toName)
        if share != 1 {
            try container.encode(share, forKey: .share)
        }
        if ratio != 1 {
            try container.encode(ratio, forKey: .ratio)
        }
        if extraTime != .zero {
            try container.encode(Int(extraTime.components.seconds), forKey: .extraSeconds)
        }
        try container.encodeIfPresent(stepNote, forKey: .stepNote)
        try container.encode(sourceID, forKey: .sourceID)
        try container.encode(quote, forKey: .quote)
    }
}

/// One goal for rewriting recipes, for example "balanced" or "blood pressure", with its own rules.
public struct RewriteGoal: Sendable, Hashable, Codable, Identifiable {
    public let id: RewriteGoalID
    public var rules: [SwapRule]

    public init(id: RewriteGoalID, rules: [SwapRule]) {
        self.id = id
        self.rules = rules
    }

    public static let balanced: RewriteGoalID = "balanced"
}

/// All rewrite goals that ship with the app, from `Resources/Evidence/rewrite-rules.json`.
public struct RewriteRules: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var goals: [RewriteGoal]

    public init(goals: [RewriteGoal], schemaVersion: Int = RewriteRules.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
        self.goals = goals
    }

    public static func bundled() throws -> RewriteRules {
        guard
            let url = Bundle.module.url(forResource: "rewrite-rules", withExtension: "json", subdirectory: "Evidence")
        else {
            throw FoodCatalog.LoadError.missingResource
        }
        return try decode(Data(contentsOf: url))
    }

    /// Decodes the rules, checking the schema version first so a newer file fails with `unsupportedSchemaVersion`.
    public static func decode(_ data: Data) throws -> RewriteRules {
        struct Header: Decodable { var schemaVersion: Int }
        let version = try JSONDecoder().decode(Header.self, from: data).schemaVersion
        guard version <= currentSchemaVersion else {
            throw FoodCatalog.LoadError.unsupportedSchemaVersion(version)
        }
        return try JSONDecoder().decode(RewriteRules.self, from: data)
    }

    public func goal(_ id: RewriteGoalID) -> RewriteGoal? {
        goals.first { $0.id == id }
    }
}

/// Something `RewriteRules.issues(in:)` found.
public enum RewriteRuleIssue: Sendable, Hashable {
    case duplicateGoal(RewriteGoalID)
    case duplicateRule(goal: RewriteGoalID, rule: SwapRuleID)
    case unknownFood(rule: SwapRuleID, food: FoodID)
    /// The rule would swap a seasoning or aromatic, which decision 26 forbids.
    case protectedFood(rule: SwapRuleID, food: FoodID)
    /// The new food's group is assessed worse than the old one's.
    case worseningSwap(SwapRuleID)
    case unknownSource(rule: SwapRuleID, source: SourceID)
    /// Share outside (0, 1], ratio not positive, negative extra time, empty name or quote.
    case invalidRule(SwapRuleID)
}

extension RewriteRules {
    /// Problems with the rules against `catalog`. Empty for a consistent rule set.
    public func issues(in catalog: FoodCatalog) -> [RewriteRuleIssue] {
        var issues: [RewriteRuleIssue] = []
        var goalIDs: Set<RewriteGoalID> = []
        for goal in goals {
            if !goalIDs.insert(goal.id).inserted {
                issues.append(.duplicateGoal(goal.id))
            }
            var ruleIDs: Set<SwapRuleID> = []
            for rule in goal.rules {
                if !ruleIDs.insert(rule.id).inserted {
                    issues.append(.duplicateRule(goal: goal.id, rule: rule.id))
                }
                issues += Self.issues(of: rule, in: catalog)
            }
        }
        return issues
    }

    private static func issues(of rule: SwapRule, in catalog: FoodCatalog) -> [RewriteRuleIssue] {
        var issues: [RewriteRuleIssue] = []
        let isValid =
            rule.share > 0 && rule.share <= 1 && rule.ratio > 0 && rule.ratio.isFinite && rule.extraTime >= .zero
            && !rule.toName.isEmpty && !rule.quote.isEmpty && rule.from != rule.to
        if !isValid {
            issues.append(.invalidRule(rule.id))
        }
        if catalog.source(rule.sourceID) == nil {
            issues.append(.unknownSource(rule: rule.id, source: rule.sourceID))
        }
        let foods = [rule.from, rule.to].map { id in (id, catalog.food(id)) }
        for (id, food) in foods {
            guard let food else {
                issues.append(.unknownFood(rule: rule.id, food: id))
                continue
            }
            if food.role == .seasoning || food.role == .aromatic {
                issues.append(.protectedFood(rule: rule.id, food: id))
            }
        }
        if let from = foods[0].1.flatMap({ catalog.group($0.group) }),
            let to = foods[1].1.flatMap({ catalog.group($0.group) }),
            to.direction.rank < from.direction.rank
        {
            issues.append(.worseningSwap(rule.id))
        }
        return issues
    }
}

extension FoodGroup.Direction {
    /// Higher is better for health; groups without an assessment rank like neutral ones.
    fileprivate var rank: Int {
        switch self {
        case .favorable: return 2
        case .neutral, .notAssessed: return 1
        case .limit: return 0
        }
    }
}
