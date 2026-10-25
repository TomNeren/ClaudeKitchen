import Testing

@testable import KitchenCore

@Suite("Cooking answers")
struct CookingAnswersTests {
    private let start = ContinuousClock.now

    private let recipe = Recipe(
        id: "test", name: "Test", tag: "", baseServings: 2, totalMinutes: 10, ingredients: [],
        steps: [
            Step(id: "s1", phase: "Vorbereiten", text: "Zwiebel schälen."),
            Step(
                id: "s2", phase: "Anschwitzen", text: "Öl zugeben und andünsten.",
                setting: DeviceSetting(heat: .celsius(120), rotation: .reverse(speed: 1), duration: .seconds(200))),
        ])

    @Test func describesTheCurrentStepWithItsSetting() {
        var session = CookingSession(recipe: recipe)
        #expect(CookingAnswers.currentStep(of: session) == "Schritt 1 von 2, Vorbereiten: Zwiebel schälen.")
        session.send(.next)
        #expect(
            CookingAnswers.currentStep(of: session)
                == "Schritt 2 von 2, Anschwitzen: Öl zugeben und andünsten. Einstellen: 120 °C, Linkslauf 1, 3 Min 20 Sek."
        )
    }

    @Test func tellsTheRemainingTime() {
        var session = CookingSession(recipe: recipe)
        #expect(CookingAnswers.remainingTime(of: session, at: start) == "Gerade läuft kein Timer.")
        session.send(.next)
        session.send(.startTimer(at: start))
        #expect(CookingAnswers.remainingTime(of: session, at: start) == "Noch 3 Minuten und 20 Sekunden.")
        session.send(.pauseTimer(at: start + .seconds(140)))
        #expect(
            CookingAnswers.remainingTime(of: session, at: start + .seconds(500))
                == "Noch 1 Minute. Der Timer ist pausiert.")
        session.send(.startTimer(at: start))
        session.send(.tick(start + .seconds(61)))
        #expect(CookingAnswers.remainingTime(of: session, at: start + .seconds(61)) == "Der Timer ist abgelaufen.")
    }

    @Test(arguments: [
        (Duration.seconds(45), "45 Sekunden"), (.seconds(60), "1 Minute"), (.seconds(61), "1 Minute und 1 Sekunde"),
        (.milliseconds(1500), "2 Sekunden"), (.seconds(1200), "20 Minuten"),
    ])
    func speaksDurations(duration: Duration, expected: String) {
        #expect(CookingAnswers.spoken(duration) == expected)
    }
}
