import KitchenCore
import SwiftUI

/// The recipes on the plan, right on the start screen, so what was bought on Sunday is still in view on Wednesday.
/// Content on solid cards, no glass.
struct PlannedStrip: View {
    let planned: [PlannedRecipe]
    let onOpen: (RecipeID) -> Void
    let onCook: (PlannedRecipe) -> Void
    let onSetDay: (PlanDay?, RecipeID) -> Void
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
                            Menu("Tag", systemImage: "calendar") {
                                PlanDayPicker(day: plan.entry.day) { onSetDay($0, plan.recipe.id) }
                            }
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

    /// Today or overdue: the day is shown in the accent colour.
    private var isDue: Bool {
        guard let day = plan.entry.day else { return false }
        return day <= PlanDay(.now, calendar: .current)
    }

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
                    .foregroundStyle(isDue ? Palette.accent : Palette.muted)
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
    /// "Mittwoch · 3 Portionen" or "3 Portionen, Vegetarisch".
    static func subtitle(for entry: MealPlan.Entry) -> String {
        let servings = Portions.text(entry.servings)
        let detail = entry.goal.map { "\(servings), \(HealthGoals.name($0))" } ?? servings
        guard let day = entry.day else { return detail }
        return "\(PlanDayText.label(day, today: PlanDay(.now, calendar: .current))) · \(detail)"
    }
}

#Preview {
    let planned = Recipe.fixtures.prefix(3).map {
        PlannedRecipe(recipe: $0, entry: MealPlan.Entry(recipe: $0.id, servings: 3))
    }
    PlannedStrip(planned: planned, onOpen: { _ in }, onCook: { _ in }, onSetDay: { _, _ in }, onRemove: { _ in })
        .background { WarmBackground() }
}

/// Menu content to choose the day of a plan entry: none, or one of the next seven days. A day outside that range
/// (past, or set further ahead) stays listed so the current choice is visible.
struct PlanDayPicker: View {
    let day: PlanDay?
    let onSelect: (PlanDay?) -> Void

    var body: some View {
        let calendar = Calendar.current
        let today = PlanDay(.now, calendar: calendar)
        var days = today.following(7, calendar: calendar)
        if let day, !days.contains(day) {
            days.insert(day, at: day < today ? 0 : days.count)
        }
        return Picker(
            "Tag", selection: Binding(get: { day }, set: { onSelect($0) })
        ) {
            Text("Ohne Tag").tag(PlanDay?.none)
            ForEach(days, id: \.self) { option in
                Text(PlanDayText.label(option, today: today, calendar: calendar)).tag(Optional(option))
            }
        }
    }
}

enum PlanDayText {
    /// "Heute", "Morgen", "Freitag" within the week, "Mo., 9. Nov." further ahead, "Überfällig (Mo.)" when past.
    static func label(_ day: PlanDay, today: PlanDay, calendar: Calendar = .current) -> String {
        guard let date = day.date(in: calendar) else { return day.description }
        if day == today { return "Heute" }
        if day == today.adding(days: 1, calendar: calendar) { return "Morgen" }
        if day < today { return "Überfällig (\(date.formatted(.dateTime.weekday(.abbreviated))))" }
        if day <= today.adding(days: 6, calendar: calendar) {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
