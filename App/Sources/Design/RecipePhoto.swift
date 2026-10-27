import KitchenCore
import SwiftUI
import UIKit

/// Layout tokens for recipe photos. Sizes and radii live here so the band and the list agree.
enum PhotoMetrics {
    static let tileWidth: CGFloat = 150
    static let tileHeight: CGFloat = 190
    static let tileCornerRadius: CGFloat = 20
    static let tileSpacing: CGFloat = 12
    /// Side of the square thumbnail in list cards, same as the letter badge it replaces.
    static let thumbnailSide: CGFloat = 52
    static let thumbnailCornerRatio: CGFloat = 0.26
}

/// A recipe photo, or a placeholder when the asset is missing.
///
/// The photo is the asset `recipe-<recipe.id.rawValue>` in the asset catalog (the id equals the JSON file name,
/// for example `recipe-mapo-tofu`). Without it a MeshGradient in the recipe's accent colour with the initial is shown.
/// Fills the space it is given; the caller clips and sizes it.
struct RecipePhoto: View {
    let recipe: Recipe
    /// Font size of the placeholder initial.
    var letterSize: CGFloat = 40

    static func assetName(for id: RecipeID) -> String { "recipe-\(id.rawValue)" }

    var body: some View {
        if let image = UIImage(named: Self.assetName(for: recipe.id)) {
            Color.clear
                .overlay { Image(uiImage: image).resizable().scaledToFill() }
                .clipped()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        let base = Palette.accent(for: recipe.id)
        let light = base.mix(with: .white, by: 0.25)
        let dark = base.mix(with: .black, by: 0.3)
        return MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.55, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                light, base, dark,
                base, light, base,
                dark, base, light,
            ]
        )
        .overlay {
            Text(recipe.name.prefix(1))
                .font(.system(size: letterSize, weight: .semibold, design: .serif))
                .foregroundStyle(Palette.cream)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    if let recipe = Recipe.fixtures.first {
        RecipePhoto(recipe: recipe)
            .frame(width: PhotoMetrics.tileWidth, height: PhotoMetrics.tileHeight)
            .clipShape(.rect(cornerRadius: PhotoMetrics.tileCornerRadius))
    }
}
