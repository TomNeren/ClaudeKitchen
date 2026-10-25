import KitchenCore
import SwiftUI

/// Editing an own recipe on the phone: one form with recipe, ingredients and steps, details one tap deeper.
/// Saving is possible once nothing blocks cooking; warnings stay visible but do not block.
struct RecipeEditorView: View {
    @State private var model: RecipeEditorModel
    @State private var editMode: EditMode = .inactive
    @State private var path: [EditorRoute] = []
    @State private var confirmsDiscard = false
    @State private var isSaving = false
    @State private var saveFailed = false
    @Environment(\.dismiss) private var dismiss
    /// Returns false when the recipe could not be stored; the editor then stays open with the changes.
    private let onSave: (Recipe) async -> Bool

    init(recipe: Recipe, isNew: Bool, onSave: @escaping (Recipe) async -> Bool) {
        self.model = RecipeEditorModel(recipe: recipe, isNew: isNew)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                RecipeSection(model: model)
                // A new ingredient or step opens right away, so it can be filled in.
                IngredientSection(model: model) { path.append(.ingredient(model.addIngredient())) }
                StepSection(model: model) { path.append(.step(model.addStep())) }
                CheckSection(model: model)
            }
            .environment(\.editMode, $editMode)
            .navigationTitle(model.isNew ? "Neues Rezept" : "Rezept bearbeiten")
            .toolbarTitleDisplayMode(.inline)
            .navigationDestination(for: EditorRoute.self) { route in
                switch route {
                case .ingredient(let id): IngredientEditorView(model: model, id: id)
                case .step(let id): StepEditorView(model: model, id: id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", role: .cancel) {
                        if model.hasChanges { confirmsDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        isSaving = true
                        Task {
                            if await onSave(model.cleanedRecipe) {
                                dismiss()
                            } else {
                                isSaving = false
                                saveFailed = true
                            }
                        }
                    }
                    .disabled(!model.canSave || isSaving)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(editMode.isEditing ? "Fertig sortiert" : "Sortieren", systemImage: "arrow.up.arrow.down") {
                        withAnimation(Motion.searchResults) {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    }
                }
            }
            .interactiveDismissDisabled(model.hasChanges)
            .alert("Speichern fehlgeschlagen", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(
                    "Das Rezept konnte nicht gesichert werden. Deine Änderungen sind noch da; versuch es gleich noch einmal."
                )
            }
            .confirmationDialog("Änderungen verwerfen?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Verwerfen", role: .destructive) { dismiss() }
                Button("Weiter bearbeiten", role: .cancel) {}
            }
        }
    }
}

enum EditorRoute: Hashable {
    case ingredient(IngredientID)
    case step(StepID)
}

private struct RecipeSection: View {
    @Bindable var model: RecipeEditorModel

    var body: some View {
        Section("Rezept") {
            TextField("Name", text: $model.recipe.name)
                .font(.headline)
            TextField("Untertitel, z. B. Asiatisch · Dampf", text: $model.recipe.tag)
            Stepper(value: $model.recipe.baseServings, in: CookingSession.defaultServingsRange) {
                LabeledContent("Portionen", value: "\(model.recipe.baseServings)")
            }
            Stepper(value: $model.recipe.totalMinutes, in: 5...600, step: 5) {
                LabeledContent("Gesamtzeit", value: "\(model.recipe.totalMinutes) Min")
            }
        }
    }
}

private struct IngredientSection: View {
    @Bindable var model: RecipeEditorModel
    let onAdd: () -> Void

    var body: some View {
        Section {
            ForEach(model.recipe.ingredients) { ingredient in
                NavigationLink(value: EditorRoute.ingredient(ingredient.id)) {
                    LabeledContent {
                        Text(AmountFormatter.string(for: ingredient.amount))
                    } label: {
                        Text(ingredient.name.isEmpty ? "Ohne Namen" : ingredient.name)
                            .foregroundStyle(ingredient.name.isEmpty ? .secondary : .primary)
                    }
                }
            }
            .onDelete { offsets in
                for id in offsets.map({ model.recipe.ingredients[$0].id }) {
                    model.recipe.removeIngredient(id)
                }
            }
            .onMove { model.recipe.moveIngredients(fromOffsets: $0, toOffset: $1) }
            Button("Zutat hinzufügen", systemImage: "plus.circle.fill", action: onAdd)
        } header: {
            Text("Zutaten (\(model.recipe.ingredients.count))")
        } footer: {
            Text("Mengen für \(model.recipe.baseServings) Portionen. Wischen zum Löschen.")
        }
    }
}

private struct StepSection: View {
    @Bindable var model: RecipeEditorModel
    let onAdd: () -> Void

    var body: some View {
        Section {
            ForEach(Array(model.recipe.steps.enumerated()), id: \.element.id) { index, step in
                NavigationLink(value: EditorRoute.step(step.id)) {
                    StepRow(number: index + 1, step: step, hasIssue: !model.issues(for: step.id).isEmpty)
                }
            }
            .onDelete { offsets in
                for id in offsets.map({ model.recipe.steps[$0].id }) {
                    model.recipe.removeStep(id)
                }
            }
            .onMove { model.recipe.moveSteps(fromOffsets: $0, toOffset: $1) }
            Button("Schritt hinzufügen", systemImage: "plus.circle.fill", action: onAdd)
        } header: {
            Text("Schritte (\(model.recipe.steps.count))")
        }
    }
}

private struct StepRow: View {
    let number: Int
    let step: Step
    let hasIssue: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("\(number). \(step.phase.isEmpty ? "Schritt" : step.phase)")
                    .font(.headline)
                if hasIssue {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Mit Hinweis")
                }
            }
            Text(step.text.isEmpty ? "Noch ohne Text" : step.text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let parts = step.setting.map(SettingFormatter.parts(of:)), !parts.isEmpty {
                Text(parts.joined(separator: " · "))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// What blocks saving (red) and what is only a hint (orange), always in view at the end of the form.
private struct CheckSection: View {
    let model: RecipeEditorModel

    var body: some View {
        let recipe = model.recipe
        let problems = model.problems
        let issues = model.issues
        if !problems.isEmpty || !issues.isEmpty {
            Section("Prüfung") {
                ForEach(problems, id: \.self) { problem in
                    Label(IssueText.text(for: problem, in: recipe), systemImage: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                }
                ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                    Label(
                        IssueText.text(for: issue, in: recipe),
                        systemImage: issue.severity == .error ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(issue.severity == .error ? Color.red : Color.orange)
                }
            }
        }
    }
}

#Preview {
    if let recipe = Recipe.fixtures.first {
        RecipeEditorView(recipe: recipe, isNew: false) { _ in true }
    }
}
