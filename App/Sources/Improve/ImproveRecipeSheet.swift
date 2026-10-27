import KitchenCore
import SwiftUI

/// Shows the feedback that will be sent, runs the request, then the proposed variant for review.
struct ImproveRecipeSheet: View {
    @State private var model: ImproveRecipeModel
    @State private var isSaving = false
    @State private var saveFailed = false
    @Environment(\.dismiss) private var dismiss
    /// Stores the variant; returns false when writing failed.
    private let onSave: (Recipe) async -> Bool

    init(model: ImproveRecipeModel, onSave: @escaping (Recipe) async -> Bool) {
        _model = State(initialValue: model)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                switch model.phase {
                case .ready:
                    feedbackSection
                case .working:
                    feedbackSection
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Claude überarbeitet das Rezept")
                        }
                    }
                case .review(let improvement, let changes):
                    review(improvement, changes: changes)
                case .failed(let message):
                    feedbackSection
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Mit Claude verbessern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .alert("Speichern fehlgeschlagen", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Die Variante konnte nicht gespeichert werden.")
            }
        }
        .onDisappear { model.cancel() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Abbrechen", role: .cancel) { dismiss() }
        }
        switch model.phase {
        case .ready, .failed:
            ToolbarItem(placement: .confirmationAction) {
                Button("Senden") { model.start() }
            }
        case .working:
            ToolbarItem(placement: .confirmationAction) {
                ProgressView()
            }
        case .review:
            ToolbarItem(placement: .bottomBar) {
                Button("Verwerfen", role: .destructive) { dismiss() }
            }
            ToolbarItem(placement: .bottomBar) {
                Button("Als Variante speichern") { save() }
                    .buttonStyle(.glassProminent)
                    .disabled(isSaving)
            }
        }
    }

    private var feedbackSection: some View {
        Section {
            if let rating = model.feedback.latestRating {
                Label("Letzte Bewertung: \(rating) von 5", systemImage: "star")
            }
            ForEach(Array(model.feedback.notes.enumerated()), id: \.offset) { _, note in
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.text)
                    Text(note.cookedAt, format: .dateTime.day().month().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Das geht an Claude")
        } footer: {
            Text("Zusammen mit dem Rezept „\(model.original.name)“ und den Grenzen des Geräts.")
        }
    }

    @ViewBuilder
    private func review(_ improvement: RecipeImprovement, changes: [VariantChange]) -> some View {
        Section("Was Claude geändert hat") {
            Text(improvement.summary)
        }
        Section("Änderungen") {
            if changes.isEmpty {
                Text("Keine Änderung an Zutaten oder Schritten.")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
                ChangeLine(change: change)
            }
        }
        if !improvement.warnings.isEmpty {
            Section("Hinweise") {
                ForEach(improvement.warnings, id: \.self) { issue in
                    Text(IssueText.text(for: issue, in: improvement.recipe))
                }
            }
        }
    }

    private func save() {
        guard case .review(let improvement, _) = model.phase else { return }
        isSaving = true
        Task {
            if await onSave(improvement.recipe) {
                dismiss()
            } else {
                saveFailed = true
            }
            isSaving = false
        }
    }
}

/// One line of the change list: what was there and what comes instead.
private struct ChangeLine: View {
    let change: VariantChange

    var body: some View {
        switch change {
        case .ingredientAdded(let new):
            line("Neue Zutat", systemImage: "plus.circle", new: ingredient(new))
        case .ingredientRemoved(let old):
            line("Zutat entfällt", systemImage: "minus.circle", old: ingredient(old))
        case .ingredientChanged(let old, let new):
            line(
                "Zutat geändert", systemImage: "arrow.triangle.2.circlepath", old: ingredient(old), new: ingredient(new)
            )
        case .stepAdded(let new):
            line("Neuer Schritt", systemImage: "plus.circle", new: new.text)
        case .stepRemoved(let old):
            line("Schritt entfällt", systemImage: "minus.circle", old: old.text)
        case .stepChanged(let old, let new):
            line(
                "Schritt geändert", systemImage: "arrow.triangle.2.circlepath",
                old: old.text == new.text ? nil : old.text, new: new.text)
        }
    }

    private func ingredient(_ ingredient: Ingredient) -> String {
        let amount = AmountFormatter.string(for: ingredient.amount)
        return amount.isEmpty ? ingredient.name : "\(amount) \(ingredient.name)"
    }

    private func line(_ title: String, systemImage: String, old: String? = nil, new: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            if let old {
                Text(old)
                    .strikethrough()
                    .foregroundStyle(.secondary)
            }
            if let new {
                Text(new)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
