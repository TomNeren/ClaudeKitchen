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

/// A hint the app shows with a goal's variant, for something rules cannot change, for example salt "to taste".
public struct GoalNote: Sendable, Hashable, Codable {
    public var text: String
    public var sourceID: SourceID
    /// The passage of the source that backs the note, verbatim.
    public var quote: String

    public init(text: String, sourceID: SourceID, quote: String) {
        self.text = text
        self.sourceID = sourceID
        self.quote = quote
    }
}

/// One goal for rewriting recipes, for example "balanced" or "blood pressure", with its own rules.
///
/// JSON shape: `{"id": "blood-pressure", "criterion": "sodium", "extends": "balanced", "rules": [], "notes": []}`.
/// `criterion` defaults to `groupRank`; `extends`, `rules` and `notes` are optional.
public struct RewriteGoal: Sendable, Hashable, Codable, Identifiable {
    /// What makes a swap better for this goal.
    public enum Criterion: String, Sendable, Hashable, Codable {
        /// The new food's group is assessed better (favorable over neutral over limit).
        case groupRank
        /// Less sodium per 100 g. Allows a seasoning to become its declared low-sodium version
        /// (`Food.lowSodiumVersionOf`).
        case sodium
        /// Fewer kcal per 100 g.
        case energyDensity
        /// Less carbohydrate per 100 g.
        case carbohydrate
    }

    public let id: RewriteGoalID
    public var criterion: Criterion
    /// A goal whose rules apply too, unless this goal has its own rule for the same food.
    public var extends: RewriteGoalID?
    public var rules: [SwapRule]
    public var notes: [GoalNote]

    public init(
        id: RewriteGoalID, criterion: Criterion = .groupRank, extends: RewriteGoalID? = nil, rules: [SwapRule],
        notes: [GoalNote] = []
    ) {
        self.id = id
        self.criterion = criterion
        self.extends = extends
        self.rules = rules
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id, criterion, extends, rules, notes
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(RewriteGoalID.self, forKey: .id)
        criterion = try container.decodeIfPresent(Criterion.self, forKey: .criterion) ?? .groupRank
        extends = try container.decodeIfPresent(RewriteGoalID.self, forKey: .extends)
        rules = try container.decodeIfPresent([SwapRule].self, forKey: .rules) ?? []
        notes = try container.decodeIfPresent([GoalNote].self, forKey: .notes) ?? []
    }

    public static let balanced: RewriteGoalID = "balanced"
    public static let bloodPressure: RewriteGoalID = "blood-pressure"
    public static let weightLoss: RewriteGoalID = "weight-loss"
    public static let lowCarb: RewriteGoalID = "low-carb"
}

/// All rewrite goals that ship with the app, from `Resources/Evidence/rewrite-rules.json`.
public struct RewriteRules: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public enum LoadError: Error, Equatable {
        case missingResource
        case unsupportedSchemaVersion(Int)
    }

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
            throw LoadError.missingResource
        }
        return try decode(Data(contentsOf: url))
    }

    /// Decodes the rules, checking the schema version first so a newer file fails with `unsupportedSchemaVersion`.
    public static func decode(_ data: Data) throws -> RewriteRules {
        struct Header: Decodable { var schemaVersion: Int }
        let version = try JSONDecoder().decode(Header.self, from: data).schemaVersion
        guard version <= currentSchemaVersion else {
            throw LoadError.unsupportedSchemaVersion(version)
        }
        return try JSONDecoder().decode(RewriteRules.self, from: data)
    }

    public func goal(_ id: RewriteGoalID) -> RewriteGoal? {
        goals.first { $0.id == id }
    }

    /// The goal with the rules and notes of the goals it extends folded in: its own rules first, then inherited
    /// rules for foods it has no rule for. Nil for an unknown goal or a cycle of `extends`.
    public func resolved(_ id: RewriteGoalID) -> RewriteGoal? {
        var chain: [RewriteGoal] = []
        var next: RewriteGoalID? = id
        while let current = next {
            guard let goal = goal(current), !chain.contains(where: { $0.id == current }) else { return nil }
            chain.append(goal)
            next = goal.extends
        }
        var result = chain[0]
        result.extends = nil
        for base in chain.dropFirst() {
            let covered = Set(result.rules.map(\.from))
            result.rules += base.rules.filter { !covered.contains($0.from) }
            result.notes += base.notes
        }
        return result
    }
}

/// Something `RewriteRules.issues(in:)` found.
public enum RewriteRuleIssue: Sendable, Hashable {
    case duplicateGoal(RewriteGoalID)
    /// The goal extends a goal that does not exist, or the `extends` chain loops.
    case unresolvableGoal(RewriteGoalID)
    case unknownNoteSource(goal: RewriteGoalID, source: SourceID)
    case emptyNote(RewriteGoalID)
    case duplicateRule(goal: RewriteGoalID, rule: SwapRuleID)
    case unknownFood(rule: SwapRuleID, food: FoodID)
    /// The rule would swap a seasoning or aromatic, which decision 26 forbids. Under the sodium criterion a
    /// seasoning may become its declared low-sodium version (decision 33).
    case protectedFood(rule: SwapRuleID, food: FoodID)
    /// The swap does not improve the goal's criterion, or it moves to a group assessed worse.
    case notImproving(SwapRuleID)
    /// A rule the goal inherits through `extends` raises the nutrient the goal's criterion lowers.
    case inheritedRuleWorsens(goal: RewriteGoalID, rule: SwapRuleID)
    /// The goal's criterion compares nutrients, but one of the foods has none.
    case missingNutrients(rule: SwapRuleID, food: FoodID)
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
            if goal.extends != nil, resolved(goal.id) == nil {
                issues.append(.unresolvableGoal(goal.id))
            }
            for note in goal.notes {
                if catalog.source(note.sourceID) == nil {
                    issues.append(.unknownNoteSource(goal: goal.id, source: note.sourceID))
                }
                if note.text.isEmpty || note.quote.isEmpty {
                    issues.append(.emptyNote(goal.id))
                }
            }
            var ruleIDs: Set<SwapRuleID> = []
            for rule in goal.rules {
                if !ruleIDs.insert(rule.id).inserted {
                    issues.append(.duplicateRule(goal: goal.id, rule: rule.id))
                }
                issues += Self.issues(of: rule, criterion: goal.criterion, in: catalog)
            }
            // Inherited rules must not reuse an ID of this goal or of each other; duplicates within one goal are
            // reported above for that goal.
            if goal.extends != nil, let resolved = resolved(goal.id) {
                var seen = Set(goal.rules.map(\.id))
                for rule in resolved.rules.dropFirst(goal.rules.count) where !seen.insert(rule.id).inserted {
                    issues.append(.duplicateRule(goal: goal.id, rule: rule.id))
                }
            }
            if let resolved = resolved(goal.id), let measure = goal.criterion.measure {
                let own = Set(goal.rules.map(\.id))
                for rule in resolved.rules where !own.contains(rule.id) && rule.worsens(measure, in: catalog) {
                    issues.append(.inheritedRuleWorsens(goal: goal.id, rule: rule.id))
                }
            }
        }
        return issues
    }

    private static func issues(
        of rule: SwapRule, criterion: RewriteGoal.Criterion, in catalog: FoodCatalog
    ) -> [RewriteRuleIssue] {
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
        let from = catalog.food(rule.from)
        let to = catalog.food(rule.to)
        for (id, food) in [(rule.from, from), (rule.to, to)] where food == nil {
            issues.append(.unknownFood(rule: rule.id, food: id))
        }
        guard let from, let to else { return issues }
        let lowSodiumVersion =
            criterion == .sodium && from.role == .seasoning && to.role == .seasoning
            && to.lowSodiumVersionOf == from.id
        if !lowSodiumVersion {
            for food in [from, to] where food.role == .seasoning || food.role == .aromatic {
                issues.append(.protectedFood(rule: rule.id, food: food.id))
            }
        }
        guard let fromRank = catalog.group(from.group)?.direction.rank,
            let toRank = catalog.group(to.group)?.direction.rank
        else { return issues }
        guard let measure = criterion.measure else {
            if toRank <= fromRank {
                issues.append(.notImproving(rule.id))
            }
            return issues
        }
        guard let fromNutrients = from.nutrients, let toNutrients = to.nutrients else {
            for food in [from, to] where food.nutrients == nil {
                issues.append(.missingNutrients(rule: rule.id, food: food.id))
            }
            return issues
        }
        let (before, after) = rule.measured(measure, from: fromNutrients, to: toNutrients)
        if toRank < fromRank || after >= before {
            issues.append(.notImproving(rule.id))
        }
        return issues
    }
}

extension SwapRule {
    /// The nutrient per 100 g of the original before and after the swap: the kept part, plus the swapped part as
    /// `ratio` grams of the new food each.
    fileprivate func measured(
        _ measure: (Nutrients) -> Double, from: Nutrients, to: Nutrients
    ) -> (before: Double, after: Double) {
        let before = measure(from)
        return (before, (1 - share) * before + share * ratio * measure(to))
    }

    /// True when the swap raises the measured nutrient. Unknown foods or missing nutrients count as not worse;
    /// the rule's own goal reports those.
    fileprivate func worsens(_ measure: (Nutrients) -> Double, in catalog: FoodCatalog) -> Bool {
        guard let from = catalog.food(self.from)?.nutrients, let to = catalog.food(self.to)?.nutrients else {
            return false
        }
        let (before, after) = measured(measure, from: from, to: to)
        return after > before
    }
}

extension RewriteGoal.Criterion {
    /// The nutrient the criterion lowers, nil for `groupRank`.
    fileprivate var measure: (@Sendable (Nutrients) -> Double)? {
        switch self {
        case .groupRank: return nil
        case .sodium: return { $0.sodiumMilligrams }
        case .energyDensity: return { $0.kcal }
        case .carbohydrate: return { $0.carbohydrate }
        }
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
