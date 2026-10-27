import Foundation
import FoundationModels
import KitchenCore

/// Answers free questions during a cook with the on-device model. Its answers are not checked against the device
/// profile or the recipe, so the screen marks them as unchecked.
@MainActor
enum CookingAssistant {
    static var isAvailable: Bool {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return false }
        return model.supportsLocale(Locale(identifier: "de_DE"))
    }

    /// A fresh session per question with the recipe as context: recipes are short, and no conversation can outgrow
    /// the context window.
    static func answer(_ question: String, session: CookingSession, device: DeviceProfile) async -> String {
        let model = LanguageModelSession(instructions: instructions(for: session, device: device))
        do {
            return try await model.respond(to: question).content
        } catch let error as LanguageModelError {
            switch error {
            case .guardrailViolation, .refusal: return "Darauf kann ich nicht antworten."
            default: return "Das konnte ich gerade nicht beantworten."
            }
        } catch {
            return "Das konnte ich gerade nicht beantworten."
        }
    }

    private static func instructions(for session: CookingSession, device: DeviceProfile) -> String {
        let recipe = session.recipe
        let ingredients = session.scaledIngredients.map { item in
            var line = "- \(item.ingredient.name): \(AmountFormatter.string(for: item.amount))"
            let substitutes = session.substitutions(for: item.ingredient).map(\.substitute.name)
            if !substitutes.isEmpty {
                line += " (Ersatz laut Rezept: \(substitutes.joined(separator: ", ")))"
            }
            return line
        }
        let steps = recipe.steps.enumerated().map { index, step in
            let setting = step.setting.map(CookingAnswers.spokenParts)?.joined(separator: ", ") ?? "keine Einstellung"
            return "\(index + 1). \(step.phase): \(step.text) [\(setting)]"
        }
        let current = session.stepIndex + 1
        return """
            Du hilfst beim Kochen mit dem \(device.name). Antworte auf Deutsch in höchstens drei kurzen Sätzen, \
            die vorgelesen werden: keine Listen, keine Sonderzeichen, Zahlen mit Einheit ausgeschrieben.
            Das Gerät kann \(device.temperatureRange.lowerBound) bis \(device.temperatureRange.upperBound) Grad, \
            Stufe \(device.forwardSpeeds.lowerBound) bis \(device.forwardSpeeds.upperBound), höchstens \
            \(Int(device.maxDuration / .seconds(60))) Minuten pro Schritt. Schlage nichts außerhalb davon vor.
            Wenn du etwas nicht sicher weißt, sag das.

            Rezept: \(recipe.name), für \(session.servings) Portionen.
            Zutaten:
            \(ingredients.joined(separator: "\n"))
            Schritte:
            \(steps.joined(separator: "\n"))
            Gerade ist Schritt \(current) von \(recipe.steps.count) dran.
            """
    }
}
