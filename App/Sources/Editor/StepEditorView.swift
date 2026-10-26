import KitchenCore
import SwiftUI

/// One step: what to do, which ingredients go in and what to set on the device. Limits come from the profile.
struct StepEditorView: View {
    @Bindable var model: RecipeEditorModel
    let id: StepID
    @FocusState private var focusesText: Bool

    var body: some View {
        if let index = model.stepIndex(id) {
            form(for: index)
        } else {
            ContentUnavailableView("Schritt gelöscht", systemImage: "trash")
        }
    }

    private func form(for index: Int) -> some View {
        let step = $model.recipe.steps[index]
        let issues = model.issues(for: id)
        return Form {
            Section("Schritt \(index + 1)") {
                TextField("Kurzname, z. B. Anschwitzen", text: step.phase)
                TextField("Was zu tun ist", text: step.text, axis: .vertical)
                    .lineLimit(3...10)
                    .focused($focusesText)
                TextField("Hinweis, optional", text: step.note.orEmpty, axis: .vertical)
            }
            IngredientPicker(selection: step.ingredientIDs, ingredients: model.recipe.ingredients)
            DeviceSection(step: step, profile: model.profile)
            if !issues.isEmpty {
                Section("Prüfung") {
                    ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                        Label(
                            IssueText.text(for: issue, in: model.recipe), systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(issue.severity == .error ? Color.red : Color.orange)
                    }
                }
            }
        }
        .editorKeyboard()
        .navigationTitle(step.wrappedValue.phase.isEmpty ? "Schritt \(index + 1)" : step.wrappedValue.phase)
        .toolbarTitleDisplayMode(.inline)
        .onAppear {
            if step.wrappedValue.text.isEmpty { focusesText = true }
        }
    }
}

/// Ticks the ingredients that go into the pot in this step, in recipe order.
private struct IngredientPicker: View {
    @Binding var selection: [IngredientID]
    let ingredients: [Ingredient]

    var body: some View {
        Section("Kommt in diesem Schritt dazu") {
            if ingredients.isEmpty {
                Text("Lege zuerst Zutaten an.")
                    .foregroundStyle(.secondary)
            }
            ForEach(ingredients) { ingredient in
                let isOn = selection.contains(ingredient.id)
                Button {
                    toggle(ingredient.id)
                } label: {
                    HStack {
                        Text(ingredient.name.isEmpty ? "Ohne Namen" : ingredient.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isOn ? Palette.herb : Color.secondary)
                            .font(.title3)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }

    private func toggle(_ id: IngredientID) {
        if selection.contains(id) {
            selection.removeAll { $0 == id }
        } else {
            // Keep the recipe's order, so the cooking screen lists them as in the ingredient list.
            let order = ingredients.map(\.id)
            selection = order.filter { selection.contains($0) || $0 == id }
        }
    }
}

private enum HeatMode: Hashable {
    case off, temperature, steam
}

private enum RotationMode: Hashable {
    case off, forward, reverse
}

/// The device console for this step: program, heat, blade, time, accessory.
private struct DeviceSection: View {
    @Binding var step: Step
    let profile: DeviceProfile

    var body: some View {
        Section {
            Toggle("Gerät einstellen", isOn: usesDevice)
            if step.setting != nil {
                Picker("Programm", selection: setting.program) {
                    ForEach(Program.allCases, id: \.self) { program in
                        Text(SettingFormatter.program(program) ?? "Manuell").tag(program)
                    }
                }
                heat
                rotation
                duration
            }
        } header: {
            Text("Gerät")
        } footer: {
            if step.setting == nil {
                Text("Aus für Schritte ohne Gerät, zum Beispiel Anrichten.")
            }
        }
        Section {
            Picker("Zubehör", selection: $step.accessory) {
                Text("Keins").tag(Accessory?.none)
                ForEach(Accessory.allCases, id: \.self) { accessory in
                    Text(accessory.displayName).tag(Accessory?.some(accessory))
                }
            }
            Toggle("Beginnt im leeren, sauberen Topf", isOn: $step.freshPot)
        }
    }

    // MARK: Heat

    @ViewBuilder private var heat: some View {
        Picker("Hitze", selection: heatMode) {
            Text("Aus").tag(HeatMode.off)
            Text("Temperatur").tag(HeatMode.temperature)
            Text("Dampf").tag(HeatMode.steam)
        }
        .pickerStyle(.segmented)
        if case .celsius(let celsius) = step.setting?.heat {
            QuickPicks(values: profile.quickTemperatures, selection: celsiusBinding(celsius)) { "\($0)°" }
            Stepper(value: celsiusBinding(celsius), in: profile.temperatureRange, step: profile.temperatureStep) {
                LabeledContent("Temperatur", value: "\(celsius) °C")
            }
        }
    }

    private var heatMode: Binding<HeatMode> {
        Binding(
            get: {
                switch step.setting?.heat {
                case .celsius: .temperature
                case .steam: .steam
                case nil: .off
                }
            },
            set: { mode in
                switch mode {
                case .off:
                    step.setting?.heat = nil
                    if step.setting?.program == .steam { step.setting?.program = .manual }
                case .temperature:
                    step.setting?.heat = .celsius(profile.suggestedCelsius)
                    if step.setting?.program == .steam { step.setting?.program = .manual }
                case .steam:
                    profile.applySteam(to: &step)
                }
            }
        )
    }

    private func celsiusBinding(_ current: Int) -> Binding<Int> {
        Binding(get: { current }, set: { step.setting?.heat = .celsius($0) })
    }

    // MARK: Blade

    @ViewBuilder private var rotation: some View {
        if step.setting?.heat != .steam {
            Picker("Rührwerk", selection: rotationMode) {
                Text("Aus").tag(RotationMode.off)
                Text("Rechts").tag(RotationMode.forward)
                Text("Linkslauf").tag(RotationMode.reverse)
            }
            .pickerStyle(.segmented)
            if let current = step.setting?.rotation {
                let range = isReverse(current) ? profile.reverseSpeeds : profile.forwardSpeeds
                // Every speed fits as one tap, so no stepper.
                LabeledContent("Stufe", value: "\(current.speed)")
                QuickPicks(values: Array(range), selection: speedBinding(current)) { "\($0)" }
            }
        }
    }

    private func isReverse(_ rotation: Rotation) -> Bool {
        if case .reverse = rotation { true } else { false }
    }

    private var rotationMode: Binding<RotationMode> {
        Binding(
            get: {
                switch step.setting?.rotation {
                case .forward: .forward
                case .reverse: .reverse
                case nil: .off
                }
            },
            set: { mode in
                let speed = step.setting?.rotation?.speed ?? profile.suggestedSpeed
                switch mode {
                case .off: step.setting?.rotation = nil
                case .forward: step.setting?.rotation = .forward(speed: min(speed, profile.forwardSpeeds.upperBound))
                case .reverse: step.setting?.rotation = .reverse(speed: min(speed, profile.reverseSpeeds.upperBound))
                }
            }
        )
    }

    private func speedBinding(_ current: Rotation) -> Binding<Int> {
        Binding(
            get: { current.speed },
            set: { speed in
                step.setting?.rotation = isReverse(current) ? .reverse(speed: speed) : .forward(speed: speed)
            }
        )
    }

    // MARK: Time

    @ViewBuilder private var duration: some View {
        Toggle("Laufzeit", isOn: hasDuration)
        if let total = step.setting?.duration.map({ Int($0 / .seconds(1)) }) {
            let maxMinutes = Int(profile.maxDuration / .seconds(60))
            QuickPicks(values: profile.quickDurations, selection: durationBinding) { SettingFormatter.duration($0) }
            Stepper(value: minutesBinding(total), in: 0...maxMinutes) {
                LabeledContent("Minuten", value: "\(total / 60)")
            }
            Stepper(value: secondsBinding(total), in: 0...59) {
                LabeledContent("Sekunden", value: "\(total % 60)")
            }
        }
    }

    private var durationBinding: Binding<Duration> {
        Binding(
            get: { step.setting?.duration ?? profile.suggestedDuration },
            set: { step.setting?.duration = $0 }
        )
    }

    private var hasDuration: Binding<Bool> {
        Binding(
            get: { step.setting?.duration != nil },
            set: { step.setting?.duration = $0 ? profile.suggestedDuration : nil }
        )
    }

    private func minutesBinding(_ total: Int) -> Binding<Int> {
        Binding(get: { total / 60 }, set: { step.setting?.duration = .seconds($0 * 60 + total % 60) })
    }

    private func secondsBinding(_ total: Int) -> Binding<Int> {
        Binding(get: { total % 60 }, set: { step.setting?.duration = .seconds(total / 60 * 60 + $0) })
    }

    // MARK: Setting

    private var usesDevice: Binding<Bool> {
        Binding(
            get: { step.setting != nil },
            set: { step.setting = $0 ? DeviceSetting() : nil }
        )
    }

    /// Only used while `step.setting` is set.
    private var setting: Binding<DeviceSetting> {
        Binding(
            get: { step.setting ?? DeviceSetting() },
            set: { step.setting = $0 }
        )
    }
}

/// A row of large one-tap values, so common settings need one tap instead of many; a stepper next to it handles
/// values in between. The current value is highlighted; the row scrolls sideways when it does not fit.
private struct QuickPicks<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    let label: (Value) -> String

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    let isSelected = value == selection
                    Button {
                        selection = value
                    } label: {
                        Text(label(value))
                            .font(.callout.weight(.semibold).monospacedDigit())
                            .frame(minWidth: 36, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(isSelected ? Palette.accent : .secondary)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
    }
}
