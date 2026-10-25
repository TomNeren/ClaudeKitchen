import KitchenCore
import SwiftUI

/// Sheet for turning any recipe into an Omni Cook recipe with Claude.
struct ImportRecipeView: View {
    @State private var model: ImportRecipeModel
    @Environment(\.dismiss) private var dismiss
    private let onSaved: @MainActor () -> Void

    init(model: ImportRecipeModel = ImportRecipeModel(), onSaved: @escaping @MainActor () -> Void) {
        self.model = model
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Rezept importieren")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen", role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) { primaryAction }
                    if case .preview = model.phase {
                        ToolbarItem(placement: .bottomBar) {
                            Button("Zurück zum Text", systemImage: "pencil") { model.edit() }
                        }
                    }
                }
        }
        .onAppear { model.refreshKey() }
        // Closing the sheet stops a running conversion, so no paid request runs on unseen.
        .onDisappear { model.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .editing:
            EditingForm(
                text: $model.text, link: $model.link, hasKey: model.hasKey, linkIsInsecure: model.linkIsInsecure)
        case .working(let label):
            ProgressView(label)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .preview(let recipe, let issues):
            ImportPreview(recipe: recipe, issues: issues)
        case .failed(let message):
            ContentUnavailableView {
                Label("Import nicht möglich", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Zurück zum Text") { model.edit() }
            }
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch model.phase {
        case .preview:
            Button("Speichern") {
                Task {
                    if await model.save() {
                        onSaved()
                        dismiss()
                    }
                }
            }
            .disabled(!model.canSave)
        default:
            Button("Umwandeln") { model.convert() }
                .disabled(!model.canConvert)
        }
    }
}

private struct EditingForm: View {
    @Binding var text: String
    @Binding var link: String
    let hasKey: Bool
    let linkIsInsecure: Bool

    var body: some View {
        Form {
            if !hasKey {
                Section {
                    Label(
                        "Für den Import brauchst du einen API-Schlüssel von Anthropic. Trag ihn in den Einstellungen ein.",
                        systemImage: "key")
                }
            }
            Section("Link") {
                TextField("https://…", text: $link)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if linkIsInsecure {
                    Text("Nur https-Links lassen sich laden.")
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                }
            }
            Section {
                TextEditor(text: $text)
                    .frame(minHeight: 240)
            } header: {
                Text("Oder Rezepttext")
            } footer: {
                Text(
                    "Zutaten und Zubereitung, zum Beispiel aus einer Website oder einem Kochbuch kopiert. Claude rechnet die Schritte auf den Omni Cook um; vor dem Speichern prüft die App alle Werte."
                )
            }
        }
    }
}

/// What Claude made of the recipe, with the device check, before anything is saved.
private struct ImportPreview: View {
    let recipe: Recipe
    let issues: [ValidationIssue]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.tag.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                    Text(recipe.name)
                        .font(.title2.weight(.semibold))
                        .fontDesign(.serif)
                    Text(
                        "≈ \(recipe.totalMinutes) Min · \(Portions.text(recipe.baseServings)) · \(recipe.steps.count) Schritte"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            if !issues.isEmpty {
                Section("Prüfung") {
                    ForEach(issues, id: \.self) { issue in
                        Label(
                            IssueText.text(for: issue),
                            systemImage: issue.severity == .error
                                ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(issue.severity == .error ? Color.red : Palette.accent)
                    }
                }
            }
            Section("Zutaten") {
                ForEach(recipe.ingredients) { ingredient in
                    HStack {
                        Text(ingredient.name)
                        Spacer()
                        Text(AmountFormatter.string(for: ingredient.amount))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            Section("Ablauf") {
                ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(index + 1). \(step.phase)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.accent)
                        Text(step.text)
                        if let parts = step.setting.map(SettingFormatter.parts(of:)), !parts.isEmpty {
                            Text(parts.joined(separator: " · "))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Palette.herb)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

#Preview("Eingabe") {
    ImportRecipeView(model: ImportRecipeModel(hasKey: true)) {}
}

#Preview("Vorschau") {
    if let recipe = Recipe.fixtures.first {
        NavigationStack {
            ImportPreview(recipe: recipe, issues: DeviceProfile.omniCook.validate(recipe, servings: 12))
        }
    }
}
