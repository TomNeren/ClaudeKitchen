import KitchenCore
import SwiftUI

/// Colour tokens from the Omni Cook artefact. Each has a light and a dark variant in the asset catalog.
enum Palette {
    static let accent = Color("AccentColor")
    static let herb = Color("Herb")
    static let cool = Color("Cool")
    static let cream = Color("Cream")
    static let surface = Color("Surface")
    static let ink = Color("Ink")
    static let muted = Color("Muted")

    /// A stable accent per recipe, so a recipe keeps its colour across launches and screens.
    static func accent(for id: RecipeID) -> Color {
        let colors = [accent, herb, cool]
        let sum = id.rawValue.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[sum % colors.count]
    }
}
