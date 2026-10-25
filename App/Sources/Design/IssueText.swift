import KitchenCore

/// German text for every validation issue, so the cook knows what to fix.
enum IssueText {
    static func text(for issue: ValidationIssue) -> String {
        let prefix = issue.stepID.map { "Schritt \($0.rawValue.dropFirst()): " } ?? ""
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
}
