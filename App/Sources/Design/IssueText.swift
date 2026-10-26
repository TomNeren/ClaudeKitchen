import KitchenCore

/// German text for every validation issue, so the cook knows what to fix.
enum IssueText {
    /// Steps are named by their position in `recipe`, which stays right after the editor reordered them.
    static func text(for issue: ValidationIssue, in recipe: Recipe) -> String {
        let prefix = issue.stepID.map { "Schritt \(recipe.stepNumber(of: $0).map(String.init) ?? "?"): " } ?? ""
        switch issue.kind {
        case .noSteps: return "Das Rezept hat keine Schritte."
        case .invalidBaseServings(let value): return "Ungültige Portionszahl \(value)."
        case .duplicateIngredientID(let id): return "Zutat doppelt: \(id)."
        case .duplicateStepID(let id): return "Schritt doppelt: \(id)."
        case .unknownIngredient(let id): return prefix + "Unbekannte Zutat \(id)."
        case .temperatureOutOfRange(let celsius): return prefix + "\(celsius) °C kann das Gerät nicht."
        case .speedOutOfRange(let rotation): return prefix + "\(SettingFormatter.rotation(rotation)) gibt es nicht."
        case .durationOutOfRange(let duration):
            return prefix + "Laufzeit \(SettingFormatter.duration(duration)) geht nicht."
        case .steamWithoutSteamer: return prefix + "Dampfgaren braucht den Dampfaufsatz."
        case .steamWithRotation: return prefix + "Im Dampfmodus gibt es keine Stufe."
        case .accessoryNotOwned(let accessory): return prefix + "Zubehör fehlt: \(accessory.displayName)."
        case .fillLevelExceeded(let liters):
            return "Etwa \(liters.formatted(.number.precision(.fractionLength(1)))) l: über der Füllmarke."
        case .boilsTooShort(let id, let required):
            let name = recipe.ingredient(id)?.name ?? "Eine Zutat"
            return prefix
                + "\(name) muss roh mindestens \(SettingFormatter.duration(required)) bei 100 °C sprudelnd kochen."
                + " Aus der Dose ist sie schon gegart."
        }
    }

    static func text(for problem: EditingProblem, in recipe: Recipe) -> String {
        switch problem {
        case .missingName: return "Das Rezept braucht einen Namen."
        case .unnamedIngredient: return "Eine Zutat hat noch keinen Namen."
        case .invalidSubstitute(let id):
            let name = recipe.ingredient(id)?.name ?? "einer Zutat"
            return "Ein Ersatz bei \(name) braucht einen Namen und einen Faktor über 0."
        case .emptyStep(let id):
            return "Schritt \(recipe.stepNumber(of: id).map(String.init) ?? "?") hat noch keinen Text."
        }
    }
}
