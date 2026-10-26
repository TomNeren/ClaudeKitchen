import KitchenCore

extension Cuisine {
    /// German name for filters and the recipe's origin line.
    var displayName: String {
        switch self {
        case .india: "Indien"
        case .thailand: "Thailand"
        case .southeastAsia: "Südostasien"
        case .china: "China"
        case .japanKorea: "Japan und Korea"
        case .turkeyLevant: "Türkei und Levante"
        case .georgia: "Georgien"
        case .europe: "Europa"
        case .mexicoPeru: "Mexiko und Peru"
        }
    }
}
