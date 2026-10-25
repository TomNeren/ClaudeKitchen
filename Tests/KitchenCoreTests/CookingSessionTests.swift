import Testing

@testable import KitchenCore

@Suite("Cooking session")
struct CookingSessionTests {
    private let start = ContinuousClock.now

    private let recipe = Recipe(
        id: "test", name: "Test", tag: "", baseServings: 3, totalMinutes: 10,
        ingredients: [
            Ingredient(id: "lentils", name: "Linsen", amount: .measured(200, .gram)),
            Ingredient(id: "bay", name: "Lorbeer", amount: .measured(1, .piece), scales: false),
        ],
        steps: [
            Step(id: "s1", phase: "A", text: "Ohne Timer"),
            Step(id: "s2", phase: "B", text: "Drei Minuten", setting: DeviceSetting(duration: .seconds(180))),
            Step(id: "s3", phase: "C", text: "Eine Minute", setting: DeviceSetting(duration: .seconds(60))),
        ])

    @Test func startsAtFirstStepWithBaseServings() {
        let session = CookingSession(recipe: recipe)
        #expect(session.stepIndex == 0)
        #expect(session.servings == 3)
        #expect(session.timer == .none)
        #expect(session.isFirstStep)
        #expect(!session.isLastStep)
    }

    @Test func navigatesWithinBoundsAndLoadsEachStepsTimer() {
        var session = CookingSession(recipe: recipe)
        session.send(.previous)
        #expect(session.stepIndex == 0)
        session.send(.next)
        #expect(session.timer == .ready(.seconds(180)))
        session.send(.next)
        #expect(session.timer == .ready(.seconds(60)))
        #expect(session.isLastStep)
        session.send(.next)
        #expect(session.stepIndex == 2)
        session.send(.goToStep(0))
        #expect(session.currentStep?.id == "s1")
        session.send(.goToStep(7))
        #expect(session.stepIndex == 0)
    }

    @Test func clampsServings() {
        var session = CookingSession(recipe: recipe, servingsRange: 1...8)
        session.send(.setServings(0))
        #expect(session.servings == 1)
        session.send(.setServings(20))
        #expect(session.servings == 8)
    }

    @Test func scalesIngredientsButNotFixedOnes() {
        var session = CookingSession(recipe: recipe)
        session.send(.setServings(6))
        let amounts = session.scaledIngredients.map(\.amount)
        #expect(amounts == [.measured(400, .gram), .measured(1, .piece)])
    }

    @Test func timerRunsFromAnEndInstant() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        #expect(session.timer == .running(endsAt: start + .seconds(180)))
        #expect(session.timer.remaining(at: start + .seconds(30)) == .seconds(150))
        session.send(.tick(start + .seconds(179)))
        #expect(session.timer == .running(endsAt: start + .seconds(180)))
        session.send(.tick(start + .seconds(180)))
        #expect(session.timer == .finished)
        #expect(session.timer.remaining(at: start + .seconds(500)) == .zero)
    }

    @Test func pauseKeepsRemainingTimeAndResumeContinues() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.pauseTimer(at: start + .seconds(60)))
        #expect(session.timer == .paused(remaining: .seconds(120)))
        session.send(.startTimer(at: start + .seconds(600)))
        #expect(session.timer == .running(endsAt: start + .seconds(720)))
    }

    @Test func pausingAfterTheEndFinishes() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.pauseTimer(at: start + .seconds(200)))
        #expect(session.timer == .finished)
    }

    @Test func resetRestoresTheStepDuration() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.resetTimer)
        #expect(session.timer == .ready(.seconds(180)))
    }

    @Test func startIsIgnoredWithoutTimerOrWhileRunning() {
        var session = CookingSession(recipe: recipe)
        session.send(.startTimer(at: start))
        #expect(session.timer == .none)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.startTimer(at: start + .seconds(10)))
        #expect(session.timer == .running(endsAt: start + .seconds(180)))
    }

    @Test func changingStepDropsARunningTimer() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.next)
        #expect(session.timer == .ready(.seconds(60)))
    }
}
