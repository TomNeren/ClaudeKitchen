import KitchenCore

/// Spoken German answers built from `CookingStatus`, with full words instead of display abbreviations.
enum CookingAnswers {
    /// "Schritt 2 von 6, Anschwitzen: Öl zugeben. Einstellen: 120 Grad, Linkslauf Stufe 1, 3 Minuten."
    static func step(_ status: CookingStatus) -> String {
        var sentence = "Schritt \(status.stepNumber) von \(status.totalSteps), \(status.phase): \(status.text)"
        let setting = status.setting.map(spokenParts) ?? []
        if !setting.isEmpty {
            sentence += " Einstellen: \(setting.joined(separator: ", "))."
        }
        return sentence
    }

    static func remainingTime(_ status: CookingStatus) -> String {
        switch status.timer {
        case .none:
            "Gerade läuft kein Timer."
        case .finished:
            "Der Timer ist abgelaufen."
        case .running(let remaining):
            "Noch \(spoken(remaining))."
        case .paused(let remaining):
            "Noch \(spoken(remaining)). Der Timer ist pausiert."
        }
    }

    static func spokenParts(_ setting: DeviceSetting) -> [String] {
        var parts: [String] = []
        if let program = SettingFormatter.program(setting.program) {
            parts.append(program)
        }
        switch setting.heat {
        case .celsius(let celsius): parts.append("\(celsius) Grad")
        case .steam where setting.program != .steam: parts.append("Dampf")
        default: break
        }
        switch setting.rotation {
        case .forward(let speed): parts.append("Stufe \(speed)")
        case .reverse(let speed): parts.append("Linkslauf Stufe \(speed)")
        case nil: break
        }
        if let duration = setting.duration {
            parts.append(spoken(duration))
        }
        return parts
    }

    /// "3 Minuten und 20 Sekunden", "1 Minute", "45 Sekunden". Rounds up to whole seconds.
    static func spoken(_ duration: Duration) -> String {
        let total = max(0, Int((duration / .seconds(1)).rounded(.up)))
        let minutes = total / 60
        let seconds = total % 60
        let minuteText = minutes == 1 ? "1 Minute" : "\(minutes) Minuten"
        let secondText = seconds == 1 ? "1 Sekunde" : "\(seconds) Sekunden"
        switch (minutes, seconds) {
        case (0, _): return secondText
        case (_, 0): return minuteText
        default: return "\(minuteText) und \(secondText)"
        }
    }
}
