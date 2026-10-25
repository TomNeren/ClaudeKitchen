import KitchenCore
import SwiftUI

/// One recipe in the library. Content, not chrome: a solid surface, no glass.
struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 16) {
            Glyph(recipe: recipe)
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.tag.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Palette.accent(for: recipe.id))
                Text(recipe.name)
                    .font(.title3.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Text("≈ \(recipe.totalMinutes) Min · \(Portions.text(recipe.baseServings))")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.muted)
                .accessibilityHidden(true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: .rect(cornerRadius: 20))
        .contentShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    if let recipe = Recipe.fixtures.first {
        RecipeCard(recipe: recipe).padding()
    }
}
