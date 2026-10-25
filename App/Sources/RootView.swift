import KitchenCore
import SwiftUI

/// Placeholder until the recipe library lands in M2.
struct RootView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Noch keine Rezepte",
                systemImage: "fork.knife",
                description: Text("Die Rezeptbibliothek folgt im nächsten Schritt.")
            )
            .navigationTitle("Omni Cook")
        }
    }
}

#Preview {
    RootView()
}
