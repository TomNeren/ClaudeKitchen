import AppIntents

/// What a Live Activity button or Siri asks the running cook to do.
enum CookingIntentCommand: Sendable {
    case next
    case previous
    case startTimer
    case pauseTimer
}

/// Connects intents to the cooking screen that is open. The app sets `handler` while the cooking mode is shown;
/// the widget extension never does, its buttons run their intents in the app's process.
@MainActor
enum CookingIntentBridge {
    static var handler: (@MainActor (CookingIntentCommand) -> Void)?

    static func perform(_ command: CookingIntentCommand) {
        handler?(command)
    }
}

struct NextStepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Nächster Schritt" }
    static var description: IntentDescription { "Geht im Kochmodus zum nächsten Schritt." }

    func perform() async throws -> some IntentResult {
        await CookingIntentBridge.perform(.next)
        return .result()
    }
}

struct PreviousStepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Vorheriger Schritt" }
    static var description: IntentDescription { "Geht im Kochmodus einen Schritt zurück." }

    func perform() async throws -> some IntentResult {
        await CookingIntentBridge.perform(.previous)
        return .result()
    }
}

struct StartTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Timer starten" }
    static var description: IntentDescription { "Startet oder setzt den Timer des aktuellen Schritts fort." }

    func perform() async throws -> some IntentResult {
        await CookingIntentBridge.perform(.startTimer)
        return .result()
    }
}

struct PauseTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Timer pausieren" }
    static var description: IntentDescription { "Pausiert den laufenden Kochtimer." }

    func perform() async throws -> some IntentResult {
        await CookingIntentBridge.perform(.pauseTimer)
        return .result()
    }
}
