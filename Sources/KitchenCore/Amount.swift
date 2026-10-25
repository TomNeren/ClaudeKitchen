import Foundation

/// A unit an ingredient is measured in.
public enum MeasureUnit: String, Sendable, Hashable, Codable, CaseIterable {
    case gram = "g"
    case piece = "Stk"
    case clove = "Zehen"
    case teaspoon = "TL"
    case tablespoon = "EL"
}

/// How much of an ingredient a recipe needs.
public enum Amount: Sendable, Hashable, Codable {
    case measured(Double, MeasureUnit)
    case toTaste

    /// Returns the amount for `servings`, given the recipe was written for `base` servings.
    /// Amounts "to taste" do not scale.
    public func scaled(from base: Int, to servings: Int) -> Amount {
        precondition(base > 0, "A recipe must be written for at least one serving.")
        switch self {
        case .measured(let value, let unit):
            return .measured(value * Double(servings) / Double(base), unit)
        case .toTaste:
            return .toTaste
        }
    }
}
