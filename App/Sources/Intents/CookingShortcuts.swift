import AppIntents
import KitchenCore

/// Answers questions about the running cook. Set by the cooking screen while it is open.
@MainActor
enum CookingQuestions {
    static var currentStep: (@MainActor () -> String)?
    static var remainingTime: (@MainActor () -> String)?
}

struct CurrentStepIntent: AppIntent {
    static var title: LocalizedStringResource { "Aktueller Schritt" }
    static var description: IntentDescription { "Liest den aktuellen Kochschritt mit Geräteeinstellung vor." }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = await MainActor.run { CookingQuestions.currentStep?() } ?? Self.noCooking
        return .result(dialog: "\(answer)")
    }

    static let noCooking = "Gerade ist kein Kochmodus offen."
}

struct RemainingTimeIntent: AppIntent {
    static var title: LocalizedStringResource { "Restzeit" }
    static var description: IntentDescription { "Sagt, wie lange der Kochtimer noch läuft." }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = await MainActor.run { CookingQuestions.remainingTime?() } ?? CurrentStepIntent.noCooking
        return .result(dialog: "\(answer)")
    }
}

struct CookingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextStepIntent(),
            phrases: ["Nächster Schritt in \(.applicationName)", "Weiter in \(.applicationName)"],
            shortTitle: "Nächster Schritt", systemImageName: "chevron.right")
        AppShortcut(
            intent: PreviousStepIntent(),
            phrases: ["Schritt zurück in \(.applicationName)", "Zurück in \(.applicationName)"],
            shortTitle: "Schritt zurück", systemImageName: "chevron.left")
        AppShortcut(
            intent: StartTimerIntent(),
            phrases: ["Timer starten in \(.applicationName)", "Starte den Timer in \(.applicationName)"],
            shortTitle: "Timer starten", systemImageName: "play.fill")
        AppShortcut(
            intent: RemainingTimeIntent(),
            phrases: ["Wie lange noch in \(.applicationName)", "Restzeit in \(.applicationName)"],
            shortTitle: "Restzeit", systemImageName: "timer")
        AppShortcut(
            intent: CurrentStepIntent(),
            phrases: [
                "Was ist der nächste Schritt in \(.applicationName)", "Aktueller Schritt in \(.applicationName)",
            ],
            shortTitle: "Aktueller Schritt", systemImageName: "text.bubble")
    }
}
