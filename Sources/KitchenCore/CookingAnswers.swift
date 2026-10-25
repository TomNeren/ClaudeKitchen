import Foundation

/// German sentences about the running cook, for Siri answers now and the voice mode later.
public enum CookingAnswers {
    /// "Schritt 2 von 6, Anschwitzen: Olivenöl zugeben und alles andünsten. Einstellen: 120 °C, Linkslauf 1, 3 Min."
    public static func currentStep(of session: CookingSession) -> String {
        guard let step = session.currentStep else { return "Dieses Rezept hat keine Schritte." }
        var sentence = "Schritt \(session.stepIndex + 1) von \(session.recipe.steps.count), \(step.phase): \(step.text)"
        if let setting = step.setting {
            let parts = SettingFormatter.parts(of: setting)
            if !parts.isEmpty {
                sentence += " Einstellen: \(parts.joined(separator: ", "))."
            }
        }
        return sentence
    }

    /// "Noch 3 Minuten und 20 Sekunden." / "Der Timer ist abgelaufen." / "Gerade läuft kein Timer."
    public static func remainingTime(of session: CookingSession, at now: ContinuousClock.Instant) -> String {
        switch session.timer {
        case .none, .ready:
            return "Gerade läuft kein Timer."
        case .finished:
            return "Der Timer ist abgelaufen."
        case .running, .paused:
            let remaining = session.timer.remaining(at: now) ?? .zero
            let paused = if case .paused = session.timer { " Der Timer ist pausiert." } else { "" }
            return "Noch \(spoken(remaining)).\(paused)"
        }
    }

    /// "3 Minuten und 20 Sekunden", "1 Minute", "45 Sekunden". Rounds up to whole seconds.
    public static func spoken(_ duration: Duration) -> String {
        let total = max(0, Int((duration / .seconds(1)).rounded(.up)))
        let minutes = total / 60
        let seconds = total % 60
        let minuteText = minutes == 1 ? "1 Minute" : "\(minutes) Minuten"
        let secondText = seconds == 1 ? "1 Sekunde" : "\(seconds) Sekunden"
        switch (minutes, seconds) {
        case (0, _):
            return secondText
        case (_, 0):
            return minuteText
        default:
            return "\(minuteText) und \(secondText)"
        }
    }
}
