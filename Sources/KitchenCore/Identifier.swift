import Foundation

/// A typed identifier. `Owner` only tags the type, so a `RecipeID` cannot be passed where a `StepID` is expected.
/// Encodes as a plain string.
public struct Identifier<Owner>: Sendable, Hashable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }
}

public typealias RecipeID = Identifier<Recipe>
public typealias IngredientID = Identifier<Ingredient>
public typealias StepID = Identifier<Step>
