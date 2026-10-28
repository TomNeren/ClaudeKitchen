import KitchenCore
import SwiftUI

/// The recipes on the plan, right on the start screen, so what was bought on Sunday is still in view on Wednesday.
/// Content on solid cards, no glass.
struct PlannedStrip: View {
    let planned: [PlannedRecipe]
    let onOpen: (RecipeID) -> Void
    let onCook: (PlannedRecipe) -> Void
    let onRemove: (RecipeID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Geplant", systemImage: "list.bullet.clipboard")
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 16)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(planned) { plan in
                        Button {
                            onOpen(plan.recipe.id)
                        } label: {
                            PlannedCard(plan: plan)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Jetzt kochen", systemImage: "play.fill") { onCook(plan) }
                            Button("Aus dem Plan entfernen", systemImage: "trash", role: .destructive) {
                                onRemove(plan.recipe.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

private struct PlannedCard: View {
    let plan: PlannedRecipe

    var body: some View {
        HStack(spacing: 12) {
            Glyph(recipe: plan.recipe, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.recipe.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Text(PlannedText.subtitle(for: plan.entry))
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(12)
        .frame(minWidth: 180, maxWidth: 260, minHeight: 64, alignment: .leading)
        .background(Palette.surface, in: .rect(cornerRadius: 16))
        .contentShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet das Rezept")
    }
}

/// Toolbar menu with the plan, one tap from anywhere on the start screen.
struct PlanMenu: View {
    let planned: [PlannedRecipe]
    let onOpen: (RecipeID) -> Void
    let onShopping: () -> Void

    var body: some View {
        Menu {
            if planned.isEmpty {
                Text("Noch nichts geplant")
            } else {
                Section("Geplant") {
                    ForEach(planned) { plan in
                        Button {
                            onOpen(plan.recipe.id)
                        } label: {
                            Text(plan.recipe.name)
                            Text(PlannedText.subtitle(for: plan.entry))
                        }
                    }
                }
            }
            Button("Einkaufsliste", systemImage: "cart", action: onShopping)
        } label: {
            Label("Kochplan", systemImage: planned.isEmpty ? "list.bullet.clipboard" : "list.bullet.clipboard.fill")
        }
        .accessibilityValue(planned.isEmpty ? "leer" : "\(planned.count) geplant")
    }
}

enum PlannedText {
    /// "3 Portionen" or "3 Portionen, Vegetarisch".
    static func subtitle(for entry: MealPlan.Entry) -> String {
        let servings = Portions.text(entry.servings)
        return entry.goal.map { "\(servings), \(HealthGoals.name($0))" } ?? servings
    }
}

#Preview {
    let planned = Recipe.fixtures.prefix(3).map {
        PlannedRecipe(recipe: $0, entry: MealPlan.Entry(recipe: $0.id, servings: 3))
    }
    PlannedStrip(planned: planned, onOpen: { _ in }, onCook: { _ in }, onRemove: { _ in })
        .background { WarmBackground() }
}
