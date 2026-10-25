import KitchenCore

/// German text for every validation issue, so the cook knows what to fix.
enum IssueText {
    /// With `recipe`, steps are named by their position; without, by their id ("s3" is step 3 in bundled recipes).
    static func text(for issue: ValidationIssue, in recipe: Recipe? = nil) -> String {
        let prefix =
            issue.stepID.map { id in
                let number = recipe?.stepNumber(of: id).map(String.init) ?? String(id.rawValue.dropFirst())
                return "Schritt \(number): "
            } ?? ""
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
        }
    }

    static func text(for problem: EditingProblem, in recipe: Recipe) -> String {
        switch problem {
        case .missingName: return "Das Rezept braucht einen Namen."
        case .unnamedIngredient: return "Eine Zutat hat noch keinen Namen."
        case .emptyStep(let id):
            return "Schritt \(recipe.stepNumber(of: id).map(String.init) ?? "?") hat noch keinen Text."
        }
    }
}
