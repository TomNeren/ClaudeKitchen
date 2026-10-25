import KitchenCore
import SwiftUI

/// The coloured initial of a recipe, as on the artefact's cards.
struct Glyph: View {
    let recipe: Recipe
    var size: CGFloat = 52

    var body: some View {
        Text(recipe.name.prefix(1))
            .font(.system(size: size * 0.5, weight: .semibold, design: .serif))
            .foregroundStyle(Palette.cream)
            .frame(width: size, height: size)
            .background(Palette.accent(for: recipe.id), in: .rect(cornerRadius: size * 0.26))
            .accessibilityHidden(true)
    }
}
