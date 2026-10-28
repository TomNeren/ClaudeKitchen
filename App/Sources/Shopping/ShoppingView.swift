import KitchenCore
import SwiftUI

/// The plan and the shopping list, sorted by aisle. Ticking items off and "Eingekauft" book them into the pantry.
struct ShoppingView: View {
    @Bindable var model: ShoppingModel
    /// Opens a planned recipe; nil leaves the rows without the action.
    var onOpenRecipe: ((RecipeID) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var exportMessage = ""
    @State private var isShowingExportMessage = false
    @State private var isExporting = false

    var body: some View {
        NavigationStack {
            List {
                if let undo = model.undo {
                    Section {
                        Button("Rückgängig: \(undo.label)", systemImage: "arrow.uturn.backward") {
                            model.undoLastBooking()
                        }
                    }
                }
                planSection
                ForEach(Aisle.allCases, id: \.self) { aisle in
                    let items = model.list.items.filter { $0.aisle == aisle }
                    if !items.isEmpty {
                        Section(ShoppingText.aisle(aisle)) {
                            ForEach(items) { item in
                                ShoppingRow(item: item, isChecked: model.isChecked(item)) { model.toggle(item) }
                            }
                        }
                    }
                }
            }
            .overlay {
                if model.planned.isEmpty && model.list.items.isEmpty {
                    ContentUnavailableView(
                        "Noch nichts geplant", systemImage: "cart",
                        description: Text("Lege Rezepte über „Auf die Einkaufsliste“ in ihrer Ansicht hierher."))
                }
            }
            .alert(exportMessage, isPresented: $isShowingExportMessage) {
                Button("OK", role: .cancel) {}
            }
            .navigationTitle("Einkauf")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        PantryView(model: model)
                    } label: {
                        Label("Vorrat", systemImage: "cabinet")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Teilen", systemImage: "square.and.arrow.up") {
                        ShareLink(
                            "Als Liste", item: ShoppingText.plainText(model.openItems),
                            preview: SharePreview("Einkaufsliste"))
                        // A brief for an agent in the cook's own, logged-in browser; checkout stays with the cook.
                        ShareLink(
                            "Für Einkaufs-Agenten", item: model.agentBrief,
                            preview: SharePreview("Einkaufsauftrag"))
                    }
                    .disabled(model.openItems.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("In Erinnerungen", systemImage: "list.bullet.rectangle") { exportToReminders() }
                        .disabled(isExporting || model.openItems.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Eingekauft", systemImage: "checkmark.circle") { model.buyChecked() }
                        .disabled(!model.hasChecked)
                }
            }
        }
    }

    @ViewBuilder
    private var planSection: some View {
        let planned = model.planned
        if !planned.isEmpty {
            Section("Geplant") {
                ForEach(planned) { plan in
                    Stepper(
                        value: Binding(
                            get: { plan.entry.servings }, set: { model.setServings($0, for: plan.recipe.id) }),
                        in: 1...max(24, plan.entry.servings)
                    ) {
                        VStack(alignment: .leading) {
                            Text(plan.recipe.name)
                            Text(PlannedText.subtitle(for: plan.entry)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("Entfernen", systemImage: "trash", role: .destructive) {
                            model.remove(plan.recipe.id)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if let onOpenRecipe {
                            Button("Öffnen", systemImage: "book") { onOpenRecipe(plan.recipe.id) }
                        }
                    }
                    .contextMenu {
                        if let onOpenRecipe {
                            Button("Rezept öffnen", systemImage: "book") { onOpenRecipe(plan.recipe.id) }
                        }
                        Button("Aus dem Plan entfernen", systemImage: "trash", role: .destructive) {
                            model.remove(plan.recipe.id)
                        }
                    }
                }
            }
        }
    }
}

extension ShoppingView {
    fileprivate func exportToReminders() {
        isExporting = true
        Task {
            exportMessage = await model.exportToReminders()
            isShowingExportMessage = true
            isExporting = false
        }
    }
}

/// One item with its tick, amount and why it is on the list.
private struct ShoppingRow: View {
    let item: ShoppingList.Item
    let isChecked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? Palette.herb : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .strikethrough(isChecked)
                    if let reason = ShoppingText.reason(item.reason) {
                        Text(reason).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(ShoppingText.quantity(item.quantity))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isChecked)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

#Preview {
    ShoppingView(model: ShoppingModel())
}
