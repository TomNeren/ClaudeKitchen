import Testing

@testable import KitchenCore

@Suite("Timer alarm")
struct TimerAlarmTests {
    private let start = ContinuousClock.now

    private let recipe = Recipe(
        id: "test", name: "Linsen", tag: "", baseServings: 2, totalMinutes: 10, ingredients: [],
        steps: [
            Step(id: "s1", phase: "Vorbereiten", text: "A"),
            Step(id: "s2", phase: "Köcheln", text: "B", setting: DeviceSetting(duration: .seconds(600))),
            Step(id: "s3", phase: "Anrichten", text: "C"),
        ])

    @Test func noAlarmWithoutARunningOrPausedTimer() {
        var session = CookingSession(recipe: recipe)
        #expect(session.alarm == nil)
        session.send(.next)
        #expect(session.alarm == nil)
    }

    @Test func runningTimerHoldsAnAlarmForItsStep() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.next)
        let alarm = session.alarm
        #expect(alarm?.phase == .running(endsAt: start + .seconds(600)))
        #expect(alarm?.stepNumber == 2)
        #expect(alarm?.stepPhase == "Köcheln")
        #expect(alarm?.recipeName == "Linsen")
    }

    @Test func pausedAndFinishedTimersSayWhatHappenedAndResetRemovesTheAlarm() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.pauseTimer(at: start + .seconds(100)))
        #expect(session.alarm?.phase == .paused)
        session.send(.resetTimer)
        #expect(session.alarm == nil)
        session.send(.startTimer(at: start))
        session.send(.tick(start + .seconds(600)))
        #expect(session.alarm?.phase == .finished)
        session.send(.next)
        #expect(session.alarm == nil)
    }
}
