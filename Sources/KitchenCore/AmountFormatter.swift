import Foundation

/// Turns amounts into German kitchen notation: "200 g", "1½ Stk", "¼ TL", "nach Geschmack".
///
/// Rounding follows what a cook can measure: grams to 5 g (to 1 g below 20 g, to 10 g from 500 g),
/// pieces, cloves and spoons to quarters, shown as fractions.
public enum AmountFormatter {
    public static let toTasteText = "nach Geschmack"

    public static func string(for amount: Amount) -> String {
        switch amount {
        case .toTaste:
            return toTasteText
        case .measured(let value, let unit):
            return "\(quantity(value, unit: unit)) \(unit.rawValue)"
        }
    }

    /// The rounded number without its unit, for example "1½" or "135", so the unit can be written or spoken.
    public static func quantity(_ value: Double, unit: MeasureUnit) -> String {
        number(rounded(value, unit: unit), unit: unit)
    }

    /// The value as it should be measured.
    public static func rounded(_ value: Double, unit: MeasureUnit) -> Double {
        switch unit {
        case .gram:
            let step: Double = value < 20 ? 1 : value < 500 ? 5 : 10
            return max(step, (value / step).rounded() * step)
        case .piece, .clove, .teaspoon, .tablespoon:
            return max(0.25, (value * 4).rounded() / 4)
        }
    }

    private static let fractions: [Int: String] = [1: "¼", 2: "½", 3: "¾"]

    private static func number(_ value: Double, unit: MeasureUnit) -> String {
        guard unit != .gram else { return String(Int(value)) }
        let whole = Int(value)
        let quarters = Int(((value - Double(whole)) * 4).rounded())
        guard let fraction = fractions[quarters] else { return String(whole) }
        return whole == 0 ? fraction : "\(whole)\(fraction)"
    }
}
