import KitchenCore
import SwiftUI

/// Recipe overview: hero, servings, scaled ingredients and the steps with their device settings.
/// Glass sits only on controls floating above content: the servings stepper and the start button.
struct RecipeDetailView: View {
    @State private var model: RecipeDetailModel
    private let onStartCooking: (_ servings: Int) -> Void
    private let isOwn: Bool
    private let onEdit: (() -> Void)?

    /// `recipe` seeds the screen model once; the screen does not follow later changes to it.
    init(
        recipe: Recipe, isOwn: Bool = false, onEdit: (() -> Void)? = nil,
        onStartCooking: @escaping (_ servings: Int) -> Void
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
                IngredientList(ingredients: model.ingredients, servings: model.servings)
                if !warnings.isEmpty {
                    WarningList(issues: warnings, recipe: model.recipe)
                }
                StepOverview(steps: model.recipe.steps)
            }
            .padding(.bottom, 96)
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
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .bottomLeading)
        .background { WarmBackground(tint: Palette.accent(for: model.recipe.id)) }
    }

    private var heroMeta: some View {
        Text("≈ \(model.recipe.totalMinutes) Min · \(model.recipe.steps.count) Schritte")
            .font(.subheadline)
            .foregroundStyle(Palette.ink.opacity(0.75))
            .monospacedDigit()
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
            RecipeDetailView(recipe: recipe) { _ in }
        }
    }
}
