import KitchenCore
import SwiftUI

/// One ingredient: name, amount for the recipe's servings, note and the curated substitutes.
struct IngredientEditorView: View {
    @Bindable var model: RecipeEditorModel
    let id: IngredientID
    @FocusState private var focusesName: Bool

    var body: some View {
        if let index = model.ingredientIndex(id) {
            form(for: index)
        } else {
            ContentUnavailableView("Zutat gelöscht", systemImage: "trash")
        }
    }

    private func form(for index: Int) -> some View {
        let ingredient = $model.recipe.ingredients[index]
        return Form {
            Section("Zutat") {
                TextField("Name, z. B. Rote Linsen", text: ingredient.name)
                    .focused($focusesName)
                TextField("Hinweis, z. B. heiß oder Dose", text: ingredient.note.orEmpty)
            }
            AmountSection(amount: ingredient.amount, servings: model.recipe.baseServings)
            Section {
                Toggle("Mit den Portionen umrechnen", isOn: ingredient.scales)
            } footer: {
                Text("Aus bei Mengen, die gleich bleiben, zum Beispiel Wasser für den Dampf.")
            }
            SubstituteSection(ingredient: ingredient, servings: model.recipe.baseServings)
        }
        .navigationTitle(ingredient.wrappedValue.name.isEmpty ? "Neue Zutat" : ingredient.wrappedValue.name)
        .toolbarTitleDisplayMode(.inline)
        .onAppear {
            if ingredient.wrappedValue.name.isEmpty { focusesName = true }
        }
    }
}

/// Quantity and unit, or "nach Geschmack".
private struct AmountSection: View {
    @Binding var amount: Amount
    let servings: Int

    var body: some View {
        Section {
            Toggle("Nach Geschmack", isOn: toTaste)
            if case .measured = amount {
                TextField("Menge", value: quantity, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                Picker("Einheit", selection: unit) {
                    ForEach(MeasureUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            }
        } header: {
            Text("Menge für \(servings) Portionen")
        } footer: {
            if case .measured = amount {
                Text(
                    "So steht es im Rezept: \(AmountFormatter.string(for: amount)). Flüssiges in Gramm, 1 ml zählt wie 1 g."
                )
            }
        }
    }

    private var toTaste: Binding<Bool> {
        Binding(
            get: { amount == .toTaste },
            set: { amount = $0 ? .toTaste : .measured(1, .piece) }
        )
    }

    private var quantity: Binding<Double> {
        Binding(
            get: { if case .measured(let value, _) = amount { value } else { 0 } },
            set: { value in
                if case .measured(_, let unit) = amount { amount = .measured(max(0, value), unit) }
            }
        )
    }

    private var unit: Binding<MeasureUnit> {
        Binding(
            get: { if case .measured(_, let unit) = amount { unit } else { .gram } },
            set: { unit in
                if case .measured(let value, _) = amount { amount = .measured(value, unit) }
            }
        )
    }
}

/// The curated substitutes, read out by the voice mode with amounts for the chosen servings.
private struct SubstituteSection: View {
    @Binding var ingredient: Ingredient
    let servings: Int

    var body: some View {
        Section {
            let amounts = ingredient.substitutions(from: servings, to: servings).map(\.amount)
            ForEach(ingredient.substitutes.indices, id: \.self) { index in
                // During a delete the amounts can briefly lag behind the rows.
                SubstituteRow(
                    substitute: substitute(at: index),
                    amount: amounts.indices.contains(index) ? amounts[index] : .toTaste)
            }
            .onDelete { ingredient.substitutes.remove(atOffsets: $0) }
            Button("Ersatz hinzufügen", systemImage: "plus.circle.fill") {
                ingredient.substitutes.append(Substitute(name: ""))
            }
        } header: {
            Text("Ersatz")
        } footer: {
            Text("Faktor 1 heißt gleiche Menge, 0,5 die Hälfte. Der Sprachmodus nennt diese Liste bei „Mir fehlt …“.")
        }
    }

    /// A row's binding that tolerates its row being deleted while SwiftUI still renders it.
    private func substitute(at index: Int) -> Binding<Substitute> {
        Binding(
            get: {
                ingredient.substitutes.indices.contains(index) ? ingredient.substitutes[index] : Substitute(name: "")
            },
            set: { if ingredient.substitutes.indices.contains(index) { ingredient.substitutes[index] = $0 } }
        )
    }
}

private struct SubstituteRow: View {
    @Binding var substitute: Substitute
    let amount: Amount

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Statt dessen, z. B. Mangold", text: $substitute.name)
                .font(.body.weight(.medium))
            HStack {
                Text("Faktor")
                    .foregroundStyle(.secondary)
                TextField("1", value: $substitute.ratio, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 80)
                Spacer()
                Text(AmountFormatter.string(for: amount))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            TextField("Hinweis, z. B. 2 Min kürzer", text: $substitute.note.orEmpty)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

extension Binding where Value == String? {
    /// An optional text as a plain one: empty means nil.
    var orEmpty: Binding<String> {
        Binding<String>(
            get: { wrappedValue ?? "" },
            set: { wrappedValue = $0.isEmpty ? nil : $0 }
        )
    }
}
