import KitchenCore
import SwiftUI

/// Where a zoom transition starts. Tiles and list cards show the same recipe, so the id also names the view.
enum ZoomSource: Hashable {
    case card(RecipeID)
    /// `row` and `copy` keep the ids unique: the drifting rows repeat their tiles.
    case tile(RecipeID, row: Int, copy: Int)

    var recipeID: RecipeID {
        switch self {
        case .card(let id), .tile(let id, _, _): id
        }
    }
}

/// Hero band under the title: two rows of photo tiles drifting in opposite directions.
/// Content, not chrome: the labels sit on a scrim, not on glass.
struct RecipeImageBand: View {
    let recipes: [Recipe]
    var cookLog = CookLog()
    /// Namespace of the zoom transition the tiles start.
    let transition: Namespace.ID
    let onOpen: (ZoomSource) -> Void

    var body: some View {
        let rows = Self.split(recipes)
        VStack(spacing: PhotoMetrics.tileSpacing) {
            if !rows.top.isEmpty {
                DriftingRow(
                    recipes: rows.top, cookLog: cookLog, direction: -1, row: 0, transition: transition, onOpen: onOpen)
            }
            if !rows.bottom.isEmpty {
                DriftingRow(
                    recipes: rows.bottom, cookLog: cookLog, direction: 1, row: 1, transition: transition, onOpen: onOpen
                )
            }
        }
        .padding(.vertical, 4)
    }

    /// Alternates recipes between the two rows.
    static func split(_ recipes: [Recipe]) -> (top: [Recipe], bottom: [Recipe]) {
        var top: [Recipe] = []
        var bottom: [Recipe] = []
        for (index, recipe) in recipes.enumerated() {
            if index.isMultiple(of: 2) { top.append(recipe) } else { bottom.append(recipe) }
        }
        return (top, bottom)
    }
}

/// Drift tokens. Speed is in points per second.
private enum Drift {
    static let speed: Double = 34
}

/// One row. Drifts endlessly, pauses while dragged and resumes on release. With Reduce Motion it is a plain scroll view.
private struct DriftingRow: View {
    let recipes: [Recipe]
    let cookLog: CookLog
    /// -1 drifts left, 1 drifts right.
    let direction: Double
    let row: Int
    let transition: Namespace.ID
    let onOpen: (ZoomSource) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewWidth: CGFloat = 0
    /// Offset at `resumedAt`; the drift is added on top while running.
    @State private var base: Double = 0
    @State private var resumedAt = Date.now
    @State private var isDragging = false
    @State private var dragTranslation: Double = 0

    private var period: Double {
        Double(recipes.count) * Double(PhotoMetrics.tileWidth + PhotoMetrics.tileSpacing)
    }

    var body: some View {
        if reduceMotion {
            ScrollView(.horizontal) {
                HStack(spacing: PhotoMetrics.tileSpacing) {
                    ForEach(recipes) { recipe in
                        RecipeTile(
                            recipe: recipe, cookLog: cookLog, source: .tile(recipe.id, row: row, copy: 0),
                            transition: transition, onOpen: onOpen)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .frame(height: PhotoMetrics.tileHeight)
        } else {
            drifting
        }
    }

    private var drifting: some View {
        // Enough copies that the row stays covered after wrapping by one period.
        let copies = max(2, Int((Double(viewWidth) / max(period, 1)).rounded(.up)) + 1)
        // The tiles live in an overlay so their width never feeds back into `viewWidth`.
        return Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: PhotoMetrics.tileHeight)
            .overlay(alignment: .leading) {
                TimelineView(.animation(paused: isDragging)) { context in
                    HStack(spacing: PhotoMetrics.tileSpacing) {
                        ForEach(0..<copies, id: \.self) { copy in
                            ForEach(recipes) { recipe in
                                RecipeTile(
                                    recipe: recipe, cookLog: cookLog, source: .tile(recipe.id, row: row, copy: copy),
                                    transition: transition, onOpen: onOpen
                                )
                                .accessibilityHidden(copy > 0)
                            }
                        }
                    }
                    .fixedSize()
                    .offset(x: wrapped(position(at: context.date)) - period)
                }
            }
            .clipped()
            .contentShape(.rect)
            .onGeometryChange(for: CGFloat.self) {
                $0.size.width
            } action: {
                viewWidth = $0
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        if !isDragging {
                            // Freeze where the row is right now, so the grab does not jump.
                            base = position(at: .now)
                            dragTranslation = 0
                            isDragging = true
                        }
                        dragTranslation = value.translation.width
                    }
                    .onEnded { value in
                        // Keep the throw the finger left behind, then resume drifting from there.
                        base += value.translation.width
                        dragTranslation = 0
                        resumedAt = .now
                        isDragging = false
                    }
            )
    }

    /// Unwrapped offset of the content at `date`.
    private func position(at date: Date) -> Double {
        if isDragging { return base + dragTranslation }
        return base + direction * Drift.speed * date.timeIntervalSince(resumedAt)
    }

    /// Maps any offset into [0, period) so the duplicated content never runs out.
    private func wrapped(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: period)
        return remainder < 0 ? remainder + period : remainder
    }
}

/// One photo tile: image, soft scrim, dish name and cuisine. Opens the recipe like a list card does.
private struct RecipeTile: View {
    let recipe: Recipe
    let cookLog: CookLog
    let source: ZoomSource
    let transition: Namespace.ID
    let onOpen: (ZoomSource) -> Void

    var body: some View {
        Button {
            onOpen(source)
        } label: {
            RecipePhoto(recipe: recipe, letterSize: 56)
                .frame(width: PhotoMetrics.tileWidth, height: PhotoMetrics.tileHeight)
                .overlay(alignment: .bottomLeading) { label }
                .overlay(alignment: .topLeading) {
                    CookedBadge(
                        lastCooked: cookLog.lastCooked(for: recipe.id), rating: cookLog.latestRating(for: recipe.id)
                    )
                    .padding(8)
                }
                .clipShape(.rect(cornerRadius: PhotoMetrics.tileCornerRadius))
                .contentShape(.rect(cornerRadius: PhotoMetrics.tileCornerRadius))
                .matchedTransitionSource(id: source, in: transition)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recipe.name)
        .accessibilityValue(
            CookedText.spoken(
                lastCooked: cookLog.lastCooked(for: recipe.id), rating: cookLog.latestRating(for: recipe.id)) ?? ""
        )
        .accessibilityHint(cuisineName ?? "")
    }

    private var cuisineName: String? { recipe.origin?.cuisine.displayName }

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(recipe.name)
                .font(.subheadline.weight(.semibold))
                .fontDesign(.serif)
                .lineLimit(2)
            if let cuisineName {
                Text(cuisineName)
                    .font(.caption2)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
        )
    }
}

#Preview {
    @Previewable @Namespace var transition
    NavigationStack {
        RecipeImageBand(recipes: Recipe.fixtures, transition: transition) { _ in }
    }
}
