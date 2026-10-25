import Foundation

/// A relative risk from a dose-response meta-analysis, for example "RR 0.92 per daily serving of whole grains".
public struct EffectEstimate: Sendable, Hashable, Codable {
    public enum Outcome: String, Sendable, Hashable, Codable {
        case allCauseMortality
    }

    public var outcome: Outcome
    public var relativeRisk: Double
    /// Bounds of the 95 % confidence interval.
    public var lower: Double
    public var upper: Double
    /// Grams in one daily serving, nil while the serving size has not been checked against the source.
    public var servingGrams: Double?
    public var sourceID: SourceID
    /// The passage of the source the numbers were checked against, verbatim.
    public var quote: String

    public init(
        outcome: Outcome, relativeRisk: Double, lower: Double, upper: Double, servingGrams: Double? = nil,
        sourceID: SourceID, quote: String
    ) {
        self.outcome = outcome
        self.relativeRisk = relativeRisk
        self.lower = lower
        self.upper = upper
        self.servingGrams = servingGrams
        self.sourceID = sourceID
        self.quote = quote
    }

    /// True when the confidence interval excludes 1, so the source finds a clear effect.
    public var isSignificant: Bool { upper < 1 || lower > 1 }
}

public typealias IntakeTargetID = Identifier<IntakeTarget>

/// A recommended amount for one or more food groups, for example "at most 300 g meat and sausage per week".
public struct IntakeTarget: Sendable, Hashable, Codable, Identifiable {
    public enum Period: String, Sendable, Hashable, Codable {
        case day
        case week
    }

    public enum Measure: String, Sendable, Hashable, Codable {
        case grams
        case servings
    }

    public let id: IntakeTargetID
    /// The groups the amount counts together, for example red meat, processed meat and poultry.
    public var groups: [FoodGroupID]
    public var measure: Measure
    public var minimum: Double?
    public var maximum: Double?
    public var period: Period
    /// Grams in one serving, when the source gives it.
    public var servingGrams: Double?
    public var sourceID: SourceID
    /// The passage of the source the numbers were checked against, verbatim.
    public var quote: String

    public init(
        id: IntakeTargetID, groups: [FoodGroupID], measure: Measure, minimum: Double? = nil, maximum: Double? = nil,
        period: Period, servingGrams: Double? = nil, sourceID: SourceID, quote: String
    ) {
        self.id = id
        self.groups = groups
        self.measure = measure
        self.minimum = minimum
        self.maximum = maximum
        self.period = period
        self.servingGrams = servingGrams
        self.sourceID = sourceID
        self.quote = quote
    }
}
