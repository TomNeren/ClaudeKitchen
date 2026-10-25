import Testing

@testable import KitchenCore

@Suite("Cooking status")
struct CookingStatusTests {
    private let start = ContinuousClock.now

    private let recipe = Recipe(
        id: "test", name: "Test", tag: "", baseServings: 2, totalMinutes: 10, ingredients: [],
        steps: [
            Step(id: "s1", phase: "Vorbereiten", text: "Zwiebel schälen."),
            Step(
                id: "s2", phase: "Anschwitzen", text: "Öl zugeben.",
                setting: DeviceSetting(heat: .celsius(120), duration: .seconds(200))),
        ])

    @Test func reportsStepAndSetting() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        let status = session.status(at: start)
        #expect(status?.stepNumber == 2)
        #expect(status?.totalSteps == 2)
        #expect(status?.phase == "Anschwitzen")
        #expect(status?.setting?.heat == .celsius(120))
        #expect(status?.timer == CookingStatus.Timer.none)
    }

    @Test func reportsTimerIncludingOneThatRanOutUnticked() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        #expect(session.status(at: start + .seconds(50))?.timer == .running(remaining: .seconds(150)))
        #expect(session.status(at: start + .seconds(300))?.timer == .finished)
        session.send(.pauseTimer(at: start + .seconds(100)))
        #expect(session.status(at: start + .seconds(900))?.timer == .paused(remaining: .seconds(100)))
    }

    @Test func noStatusWithoutSteps() {
        let empty = Recipe(id: "e", name: "E", tag: "", baseServings: 1, totalMinutes: 1, ingredients: [], steps: [])
        #expect(CookingSession(recipe: empty).status(at: start) == nil)
    }
}
