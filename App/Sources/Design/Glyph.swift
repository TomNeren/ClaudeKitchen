import KitchenCore
import SwiftUI

/// The coloured initial of a recipe, as on the artefact's cards. Scales with Dynamic Type.
struct Glyph: View {
    let recipe: Recipe
    private let size: CGFloat
    @ScaledMetric(relativeTo: .title) private var scale: CGFloat = 1

    init(recipe: Recipe, size: CGFloat = 52) {
        self.recipe = recipe
        self.size = size
    }

    var body: some View {
        let side = size * scale
        Text(recipe.name.prefix(1))
            .font(.system(size: side * 0.5, weight: .semibold, design: .serif))
            .foregroundStyle(Palette.cream)
            .frame(width: side, height: side)
            .background(Palette.accent(for: recipe.id), in: .rect(cornerRadius: side * 0.26))
            .accessibilityHidden(true)
    }
}
