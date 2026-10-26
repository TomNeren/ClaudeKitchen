import KitchenCore
import SwiftUI

/// The plan and the shopping list, sorted by aisle. Ticking items off and "Eingekauft" book them into the pantry.
struct ShoppingView: View {
    @Bindable var model: ShoppingModel
    @Environment(\.dismiss) private var dismiss

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
                    ShareLink(
                        item: ShoppingText.plainText(model.list, checked: model.state.checked),
                        preview: SharePreview("Einkaufsliste")
                    ) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.list.items.isEmpty)
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
                            Text(subtitle(for: plan.entry)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("Entfernen", systemImage: "trash", role: .destructive) {
                            model.remove(plan.recipe.id)
                        }
                    }
                    .contextMenu {
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
    fileprivate func subtitle(for entry: MealPlan.Entry) -> String {
        let servings = Portions.text(entry.servings)
        return entry.goal.map { "\(servings), \(HealthGoals.name($0))" } ?? servings
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
