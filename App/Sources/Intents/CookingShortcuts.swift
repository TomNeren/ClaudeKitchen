import AppIntents

struct CurrentStepIntent: AppIntent {
    static var title: LocalizedStringResource { "Aktueller Schritt" }
    static var description: IntentDescription { "Liest den aktuellen Kochschritt mit Geräteeinstellung vor." }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(await CookingIntentBridge.perform(.currentStep))")
    }
}

struct RemainingTimeIntent: AppIntent {
    static var title: LocalizedStringResource { "Restzeit" }
    static var description: IntentDescription { "Sagt, wie lange der Kochtimer noch läuft." }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(await CookingIntentBridge.perform(.remainingTime))")
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
            phrases: ["Welcher Schritt ist dran in \(.applicationName)", "Aktueller Schritt in \(.applicationName)"],
            shortTitle: "Aktueller Schritt", systemImageName: "text.bubble")
    }
}
