import KitchenCore
import SwiftUI

/// One recipe in the library. Content, not chrome: a solid surface, no glass.
struct RecipeCard: View {
    let recipe: Recipe
    var cookLog = CookLog()

    var body: some View {
        HStack(spacing: 16) {
            RecipeThumbnail(recipe: recipe)
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
                if let text = CookedText.short(
                    lastCooked: cookLog.lastCooked(for: recipe.id), rating: cookLog.latestRating(for: recipe.id))
                {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
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

/// Rounded square photo in the card, scaling with Dynamic Type like the badge it replaced.
private struct RecipeThumbnail: View {
    let recipe: Recipe
    @ScaledMetric(relativeTo: .title) private var scale: CGFloat = 1

    var body: some View {
        let side = PhotoMetrics.thumbnailSide * scale
        RecipePhoto(recipe: recipe, letterSize: side * 0.5)
            .frame(width: side, height: side)
            .clipShape(.rect(cornerRadius: side * PhotoMetrics.thumbnailCornerRatio))
            .accessibilityHidden(true)
    }
}
