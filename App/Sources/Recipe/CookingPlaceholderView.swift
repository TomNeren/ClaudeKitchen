import KitchenCore
import SwiftUI

/// Stand-in for the cooking mode until milestone M3.
struct CookingPlaceholderView: View {
    let recipe: Recipe
    let servings: Int

    var body: some View {
        ContentUnavailableView(
            "Kochmodus folgt", systemImage: "frying.pan",
            description: Text(
                "Die Schritt-für-Schritt-Führung für \(recipe.name) (\(Portions.text(servings))) kommt im nächsten Meilenstein."
            ))
    }
}
