import KitchenCore
import SwiftUI

/// Recipe overview: hero, servings, scaled ingredients and the steps with their device settings.
/// Glass sits only on controls floating above content: the servings stepper and the start button.
struct RecipeDetailView: View {
    @State private var model: RecipeDetailModel
    private let onStartCooking: (_ servings: Int) -> Void

    /// `recipe` seeds the screen model once; the screen does not follow later changes to it.
    init(recipe: Recipe, onStartCooking: @escaping (_ servings: Int) -> Void) {
        self.model = RecipeDetailModel(recipe: recipe)
        self.onStartCooking = onStartCooking
    }

    var body: some View {
        let warnings = model.warnings
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                IngredientList(ingredients: model.ingredients, servings: model.servings)
                if !warnings.isEmpty {
                    WarningList(issues: warnings)
                }
                StepOverview(steps: model.recipe.steps)
            }
            .padding(.bottom, 96)
        }
        .background { WarmBackground(tint: Palette.accent(for: model.recipe.id)) }
        .navigationTitle(model.recipe.name)
        .toolbarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            Button {
                onStartCooking(model.servings)
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

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            WarmBackground(tint: Palette.accent(for: model.recipe.id))
                .frame(height: 260)
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
                HStack {
                    Text("≈ \(model.recipe.totalMinutes) Min · \(model.recipe.steps.count) Schritte")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink.opacity(0.75))
                        .monospacedDigit()
                    Spacer()
                    ServingsStepper(model: model)
                }
            }
            .padding(20)
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(issues, id: \.self) { issue in
                Label(text(for: issue), systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.horizontal, 16)
    }

    private func text(for issue: ValidationIssue) -> String {
        switch issue.kind {
        case .fillLevelExceeded(let liters):
            return "Etwa \(liters.formatted(.number.precision(.fractionLength(1)))) l: über der Füllmarke."
        case .accessoryNotOwned(let accessory):
            return "Braucht Zubehör, das nicht im Bestand ist: \(accessory.displayName)."
        default:
            return "Hinweis zum Rezept."
        }
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
            RecipeDetailView(recipe: recipe) { _ in }
        }
    }
}
