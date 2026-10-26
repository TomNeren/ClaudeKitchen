import KitchenCore
import SwiftUI

/// Recipe overview: hero, servings, health goal, scaled ingredients and the steps with their device settings.
/// Glass sits only on controls floating above content: the goal menu, the servings stepper and the start button.
struct RecipeDetailView: View {
    @State private var model: RecipeDetailModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let onStartCooking: (_ servings: Int, _ goal: RewriteGoalID?) -> Void
    private let isOwn: Bool
    private let onEdit: (() -> Void)?

    /// `recipe` seeds the screen model once; the screen does not follow later changes to it.
    init(
        recipe: Recipe, isOwn: Bool = false, onEdit: (() -> Void)? = nil,
        onStartCooking: @escaping (_ servings: Int, _ goal: RewriteGoalID?) -> Void
    ) {
        self.isOwn = isOwn
        self.onEdit = onEdit
        self.model = RecipeDetailModel(recipe: recipe)
        self.onStartCooking = onStartCooking
    }

    var body: some View {
        let warnings = model.warnings
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                if let variant = model.variant {
                    VariantSection(variant: variant, original: model.recipe, profile: model.profile)
                }
                IngredientList(ingredients: model.ingredients, servings: model.servings)
                if !warnings.isEmpty {
                    WarningList(issues: warnings, recipe: model.displayed)
                }
                StepOverview(steps: model.displayed.steps)
                OriginSection(recipe: model.recipe)
            }
            .padding(.bottom, 96)
            // With Reduce Motion the content switches in place instead of sliding the lists below.
            .animation(reduceMotion ? nil : Motion.variantChange, value: model.goal)
        }
        .background { WarmBackground(tint: Palette.accent(for: model.recipe.id)) }
        .navigationTitle(model.recipe.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if let onEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(
                        isOwn ? "Bearbeiten" : "Als eigenes Rezept bearbeiten", systemImage: "pencil", action: onEdit)
                }
            }
        }
        .safeAreaBar(edge: .bottom) {
            Button {
                onStartCooking(model.servings, model.goal)
            } label: {
                Label("Kochen starten", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(Palette.cream)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.accent(for: model.recipe.id))
            .controlSize(.extraLarge)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    /// Grows with Dynamic Type instead of clipping: a minimum height, not a fixed one.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Glyph(recipe: model.recipe, size: 64)
            Text(model.recipe.tag.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Palette.ink.opacity(0.75))
            Text(model.recipe.name)
                .font(.largeTitle.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(Palette.ink)
            heroControls
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .bottomLeading)
        .background { WarmBackground(tint: Palette.accent(for: model.recipe.id)) }
    }

    /// The two glass controls over the hero share one container, so they sample the gradient together. The goal
    /// menu has its own row, so a longer goal name never reflows the time and the stepper.
    private var heroControls: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        heroMeta
                        Spacer()
                        ServingsStepper(model: model)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        heroMeta
                        ServingsStepper(model: model)
                    }
                }
                if !model.goals.isEmpty {
                    GoalMenu(model: model)
                }
            }
        }
    }

    private var heroMeta: some View {
        Text("≈ \(model.displayed.totalMinutes) Min · \(model.displayed.steps.count) Schritte")
            .font(.subheadline)
            .foregroundStyle(Palette.ink.opacity(0.75))
            .monospacedDigit()
    }
}

/// Goal choice floating over the hero gradient: the original or a variant for one health goal.
private struct GoalMenu: View {
    @Bindable var model: RecipeDetailModel

    var body: some View {
        Menu {
            Picker("Variante", selection: $model.goal) {
                Text("Original").tag(RewriteGoalID?.none)
                ForEach(model.goals, id: \.self) { goal in
                    Text(HealthGoals.name(goal)).tag(Optional(goal))
                }
            }
        } label: {
            Label(model.goal.map(HealthGoals.name) ?? "Original", systemImage: "leaf")
                .font(.headline)
                .frame(minHeight: 44)
        }
        .buttonStyle(.glass)
        .sensoryFeedback(.selection, trigger: model.goal)
        .accessibilityLabel("Variante")
        .accessibilityValue(model.goal.map(HealthGoals.name) ?? "Original")
    }
}

/// Servings control floating over the hero gradient: one glass capsule with two buttons.
private struct ServingsStepper: View {
    let model: RecipeDetailModel

    var body: some View {
        HStack(spacing: 4) {
            Button("Weniger", systemImage: "minus") { withAnimation(Motion.servings) { model.decrease() } }
                .disabled(!model.canDecrease)
            Text("\(model.servings)")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(model.servings)))
                .frame(minWidth: 28)
                .accessibilityHidden(true)
            Button("Mehr", systemImage: "plus") { withAnimation(Motion.servings) { model.increase() } }
                .disabled(!model.canIncrease)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .font(.title3.weight(.semibold))
        .frame(minHeight: 44)
        .padding(.horizontal, 8)
        .glassEffect(.regular, in: .capsule)
        .sensoryFeedback(.selection, trigger: model.servings)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Portionen")
        .accessibilityValue("\(model.servings)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: model.increase()
            case .decrement: model.decrease()
            @unknown default: break
            }
        }
    }
}

/// What the chosen goal changed, why, and what it does to one serving. Content, so no glass.
private struct VariantSection: View {
    let variant: RecipeVariant
    let original: Recipe
    let profile: DeviceProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Was sich ändert")
            VStack(alignment: .leading, spacing: 14) {
                if variant.changes.isEmpty && variant.rewrite.skipped.isEmpty {
                    Text("Für \(HealthGoals.name(variant.goal.id)) gibt es in diesem Rezept nichts zu tauschen.")
                        .foregroundStyle(Palette.muted)
                }
                ForEach(variant.changes, id: \.change) { detail in
                    ChangeRow(detail: detail)
                }
                ForEach(variant.rewrite.skipped, id: \.self) { skipped in
                    Label(HealthGoals.text(for: skipped, in: original, profile: profile), systemImage: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(Palette.muted)
                }
                ForEach(variant.notes, id: \.self) { note in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(note.note.text, systemImage: "lightbulb")
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink)
                        SourceDisclosure(quote: note.note.quote, source: note.source)
                    }
                }
                NutritionComparison(
                    before: variant.nutritionBefore, after: variant.nutritionAfter,
                    uncounted: uncountedNames)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: .rect(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
    }

    /// Names of the ingredients left out of either side of the comparison, in recipe order.
    private var uncountedNames: [String] {
        let ids = Set(variant.nutritionBefore.uncounted + variant.nutritionAfter.uncounted)
        return (original.ingredients + variant.recipe.ingredients)
            .filter { ids.contains($0.id) }
            .map(\.name)
            .reduce(into: [String]()) { names, name in
                if !names.contains(name) { names.append(name) }
            }
    }
}

private struct ChangeRow: View {
    let detail: ChangeDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(detail.originalName).foregroundStyle(Palette.muted).strikethrough()
                Image(systemName: "arrow.right").foregroundStyle(Palette.herb).accessibilityHidden(true)
                Text(detail.newName).foregroundStyle(Palette.ink).fontWeight(.semibold)
                if detail.rule.share < 1 {
                    Text(HealthGoals.shareText(detail.rule.share)).font(.footnote).foregroundStyle(Palette.muted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(detail.originalName) wird \(detail.rule.share < 1 ? HealthGoals.shareText(detail.rule.share) + " " : "")zu \(detail.newName)"
            )
            if let note = detail.rule.stepNote {
                Text(note).font(.footnote).foregroundStyle(Palette.muted)
            }
            SourceDisclosure(quote: detail.rule.quote, source: detail.source)
        }
    }
}

/// The verbatim passage and the citation behind a change or note, folded away until asked for.
private struct SourceDisclosure: View {
    let quote: String
    let source: EvidenceSource?

    var body: some View {
        DisclosureGroup("Quelle") {
            VStack(alignment: .leading, spacing: 6) {
                Text("„\(quote)“").italic()
                if let source {
                    Text(source.citation).font(.footnote).foregroundStyle(Palette.muted)
                }
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.footnote)
        .tint(Palette.cool)
    }
}

/// Per-serving nutrients of the original and the variant side by side.
private struct NutritionComparison: View {
    let before: NutritionFacts
    let after: NutritionFacts
    /// Ingredients missing from either column, named so a "better" number is not mistaken for a real change.
    let uncounted: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pro Portion")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
            VStack(spacing: 6) {
                row("Energie", before.kcal, after.kcal, unit: "kcal")
                row("Kohlenhydrate", before.carbohydrate, after.carbohydrate, unit: "g")
                row("Gesättigte Fette", before.saturatedFat, after.saturatedFat, unit: "g")
                row("Natrium", before.sodiumMilligrams, after.sodiumMilligrams, unit: "mg")
            }
            .font(.subheadline)
            if !uncounted.isEmpty {
                Text("Nicht mitgezählt: \(uncounted.formatted(.list(type: .and))).")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    private func row(_ label: String, _ before: Double, _ after: Double, unit: String) -> some View {
        // Wraps under accessibility sizes instead of truncating the numbers.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).foregroundStyle(Palette.muted)
                Spacer()
                value(before, after, unit: unit)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).foregroundStyle(Palette.muted)
                value(before, after, unit: unit)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): vorher \(Self.format(before)), nachher \(Self.format(after)) \(unit)")
    }

    private func value(_ before: Double, _ after: Double, unit: String) -> some View {
        Text("\(Self.format(before)) → \(Self.format(after)) \(unit)")
            .monospacedDigit()
            .foregroundStyle(after < before ? Palette.herb : Palette.ink)
            .fontWeight(after < before ? .semibold : .regular)
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}

/// Where a traditional recipe comes from, what it draws on, and what still needs a knowing eye. Hidden for
/// recipes without any of it.
private struct OriginSection: View {
    let recipe: Recipe

    var body: some View {
        if recipe.origin != nil || !recipe.references.isEmpty || !recipe.authenticityChecks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Herkunft")
                VStack(alignment: .leading, spacing: 10) {
                    if let origin = recipe.origin {
                        Text([origin.cuisine.displayName, origin.region].compactMap { $0 }.joined(separator: " · "))
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                    }
                    ForEach(recipe.references, id: \.self) { reference in
                        Label(Self.text(for: reference), systemImage: "book.closed")
                            .font(.subheadline)
                            .foregroundStyle(Palette.muted)
                    }
                    if !recipe.authenticityChecks.isEmpty {
                        Text("Zum Prüfen beim ersten Kochen")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        ForEach(recipe.authenticityChecks, id: \.self) { check in
                            Label(check, systemImage: "checkmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: .rect(cornerRadius: 16))
            }
            .padding(.horizontal, 16)
        }
    }

    private static func text(for reference: RecipeReference) -> String {
        let byline = [reference.author, reference.year.map(String.init)].compactMap { $0 }.joined(separator: ", ")
        return byline.isEmpty ? reference.title : "\(reference.title) (\(byline))"
    }
}

private struct IngredientList: View {
    let ingredients: [(ingredient: Ingredient, text: String)]
    let servings: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Zutaten für \(Portions.text(servings))")
            VStack(spacing: 0) {
                ForEach(ingredients, id: \.ingredient.id) { item in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.ingredient.name).foregroundStyle(Palette.ink)
                            if let note = item.ingredient.note {
                                Text(note).font(.footnote).foregroundStyle(Palette.muted)
                            }
                        }
                        Spacer()
                        Text(item.text)
                            .monospacedDigit()
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .accessibilityElement(children: .combine)
                    if item.ingredient.id != ingredients.last?.ingredient.id {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .background(Palette.surface, in: .rect(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
    }
}

private struct WarningList: View {
    let issues: [ValidationIssue]
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(issues, id: \.self) { issue in
                Label(IssueText.text(for: issue, in: recipe), systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct StepOverview: View {
    let steps: [Step]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Ablauf")
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(index + 1)")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(Palette.muted)
                        .frame(width: 24, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.phase.uppercased())
                            .font(.caption.weight(.bold))
                            .tracking(0.6)
                            .foregroundStyle(Palette.accent)
                        Text(step.text).foregroundStyle(Palette.ink)
                        if let parts = step.setting.map(SettingFormatter.parts(of:)), !parts.isEmpty {
                            Text(parts.joined(separator: " · "))
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(Palette.herb)
                        }
                        if let accessory = step.accessory {
                            Label(accessory.displayName, systemImage: "square.stack.3d.up")
                                .font(.footnote)
                                .foregroundStyle(Palette.cool)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: .rect(cornerRadius: 16))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title2.weight(.semibold))
            .fontDesign(.serif)
            .foregroundStyle(Palette.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

extension Accessory {
    var displayName: String {
        switch self {
        case .steamer: "Dampfaufsatz"
        case .basket: "Garkorb"
        case .whisk: "Rühraufsatz"
        }
    }
}

#Preview {
    if let recipe = Recipe.fixtures.first {
        NavigationStack {
            RecipeDetailView(recipe: recipe) { _, _ in }
        }
    }
}
