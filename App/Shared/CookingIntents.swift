import AppIntents

/// What a Live Activity button or Siri asks the running cook.
enum CookingIntentCommand: Sendable {
    case next
    case previous
    case startTimer
    case pauseTimer
    case currentStep
    case remainingTime
}

/// The open cooking screen, as seen by intents.
@MainActor
protocol CookingIntentTarget: AnyObject {
    /// Carries out `command`, waits until the Lock Screen and the alarm reflect it, and returns what to say.
    func perform(_ command: CookingIntentCommand) async -> String
}

/// Connects intents to the cooking screen that is open. The app sets `current` while the cooking mode is shown;
/// the widget extension never does, its buttons run their intents in the app's process.
@MainActor
enum CookingIntentBridge {
    static weak var current: (any CookingIntentTarget)?

    static let noCooking = "Gerade ist kein Kochmodus offen."

    static func perform(_ command: CookingIntentCommand) async -> String {
        guard let current else { return noCooking }
        return await current.perform(command)
    }
}

struct NextStepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Nächster Schritt" }
    static var description: IntentDescription { "Geht im Kochmodus zum nächsten Schritt und liest ihn vor." }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(await CookingIntentBridge.perform(.next))")
    }
}

struct PreviousStepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Vorheriger Schritt" }
    static var description: IntentDescription { "Geht im Kochmodus einen Schritt zurück und liest ihn vor." }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(await CookingIntentBridge.perform(.previous))")
    }
}

struct StartTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Timer starten" }
    static var description: IntentDescription { "Startet oder setzt den Timer des aktuellen Schritts fort." }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(await CookingIntentBridge.perform(.startTimer))")
    }
}

struct PauseTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Timer pausieren" }
    static var description: IntentDescription { "Pausiert den laufenden Kochtimer." }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(await CookingIntentBridge.perform(.pauseTimer))")
    }
}
