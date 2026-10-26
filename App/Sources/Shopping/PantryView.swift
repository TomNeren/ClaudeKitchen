import KitchenCore
import SwiftUI

/// What is at home: grams with an optional minimum for basics, "da, fast leer, leer" for seasonings.
struct PantryView: View {
    @Bindable var model: ShoppingModel
    @State private var isAdding = false

    var body: some View {
        List {
            ForEach(model.pantryItems) { entry in
                PantryRow(item: entry.item, name: entry.name) { changed in
                    model.setPantryItem(changed, for: entry.item.food)
                }
                .swipeActions {
                    Button("Entfernen", systemImage: "trash", role: .destructive) {
                        model.setPantryItem(nil, for: entry.item.food)
                    }
                }
            }
        }
        .overlay {
            if model.pantryItems.isEmpty {
                ContentUnavailableView(
                    "Vorrat ist leer", systemImage: "cabinet",
                    description: Text("Was du einkaufst, landet hier. Du kannst auch selbst etwas hinzufügen."))
            }
        }
        .navigationTitle("Vorrat")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Hinzufügen", systemImage: "plus") { isAdding = true }
                    .disabled(model.catalog == nil)
            }
        }
        .sheet(isPresented: $isAdding) {
            FoodPicker(foods: model.catalog?.foods.filter { $0.id != Food.water } ?? []) { food in
                model.setPantryItem(model.newPantryItem(for: food), for: food.id)
            }
        }
    }
}

private struct PantryRow: View {
    let item: PantryItem
    let name: String
    let onChange: (PantryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.headline)
            switch item.stock {
            case .level(let level):
                Picker("Füllstand", selection: Binding(get: { level }, set: { set(.level($0)) })) {
                    ForEach(SupplyLevel.allCases, id: \.self) { Text(ShoppingText.level($0)).tag($0) }
                }
                .pickerStyle(.segmented)
            case .grams(let grams):
                Stepper(value: Binding(get: { grams }, set: { set(.grams(max(0, $0))) }), step: 50) {
                    Text("Da: \(AmountFormatter.string(for: .measured(grams, .gram)))")
                }
                Stepper(
                    value: Binding(
                        get: { item.minimumGrams ?? 0 },
                        set: { minimum in
                            var changed = item
                            changed.minimumGrams = minimum > 0 ? minimum : nil
                            onChange(changed)
                        }),
                    in: 0...10_000, step: 100
                ) {
                    Text(
                        item.minimumGrams.map { "Mindestens: \(AmountFormatter.string(for: .measured($0, .gram)))" }
                            ?? "Kein Mindestbestand")
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    private func set(_ stock: PantryItem.Stock) {
        var changed = item
        changed.stock = stock
        onChange(changed)
    }
}

/// Searchable list of catalog foods to add to the pantry.
private struct FoodPicker: View {
    let foods: [Food]
    let onPick: (Food) -> Void
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(filtered) { food in
                Button(food.name) {
                    onPick(food)
                    dismiss()
                }
            }
            .searchable(text: $query, prompt: "Lebensmittel")
            .navigationTitle("Zum Vorrat")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private var filtered: [Food] {
        let sorted = foods.sorted { $0.name < $1.name }
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return sorted }
        return sorted.filter { food in
            words.allSatisfy { word in
                food.name.localizedStandardContains(word)
                    || food.aliases.contains { $0.localizedStandardContains(word) }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PantryView(model: ShoppingModel())
    }
}
