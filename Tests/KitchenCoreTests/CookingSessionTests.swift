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
            Step(id: "s1", phase: "A", text: "Ohne Timer", ingredientIDs: ["lentils", "bay"]),
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

    @Test func changingStepKeepsARunningTimerForItsStep() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.next)
        #expect(session.timer == .running(endsAt: start + .seconds(180)))
        #expect(session.timerStepIndex == 1)
        #expect(session.isTimerFromOtherStep)
        session.send(.previous)
        #expect(!session.isTimerFromOtherStep)
        #expect(session.timer == .running(endsAt: start + .seconds(180)))
    }

    @Test func resetOnAnotherStepLoadsThatStepsTimer() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.next)
        session.send(.resetTimer)
        #expect(session.timer == .ready(.seconds(60)))
        #expect(session.timerStepIndex == 2)
    }

    @Test func finishedTimerIsReplacedOnTheNextMove() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.tick(start + .seconds(180)))
        session.send(.next)
        #expect(session.timer == .ready(.seconds(60)))
    }

    @Test func countsEveryFinishedTimerOnce() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.tick(start + .seconds(180)))
        session.send(.tick(start + .seconds(181)))
        #expect(session.finishedTimerCount == 1)
        session.send(.resetTimer)
        session.send(.startTimer(at: start))
        session.send(.pauseTimer(at: start + .seconds(200)))
        #expect(session.finishedTimerCount == 2)
    }

    @Test func tickWhilePausedChangesNothing() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.pauseTimer(at: start + .seconds(60)))
        session.send(.tick(start + .seconds(1000)))
        #expect(session.timer == .paused(remaining: .seconds(120)))
        #expect(session.finishedTimerCount == 0)
    }

    @Test func startAfterFinishNeedsAReset() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.tick(start + .seconds(180)))
        session.send(.startTimer(at: start + .seconds(200)))
        #expect(session.timer == .finished)
        session.send(.resetTimer)
        session.send(.startTimer(at: start + .seconds(200)))
        #expect(session.timer == .running(endsAt: start + .seconds(380)))
    }

    @Test func pausingExactlyAtTheEndFinishes() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.pauseTimer(at: start + .seconds(180)))
        #expect(session.timer == .finished)
        #expect(session.finishedTimerCount == 1)
    }

    @Test func timerFromAnotherStepFinishesThenResetLoadsTheCurrentStep() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.next)
        session.send(.tick(start + .seconds(180)))
        #expect(session.timer == .finished)
        #expect(session.timerStepIndex == 1)
        #expect(session.finishedTimerCount == 1)
        session.send(.resetTimer)
        #expect(session.timer == .ready(.seconds(60)))
        #expect(session.timerStepIndex == 2)
    }

    @Test func servingsChangeDoesNotTouchARunningTimer() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.setServings(6))
        #expect(session.servings == 6)
        #expect(session.timer == .running(endsAt: start + .seconds(180)))
    }

    @Test func goingToTheCurrentStepKeepsItsTimer() {
        var session = CookingSession(recipe: recipe)
        session.send(.next)
        session.send(.startTimer(at: start))
        session.send(.goToStep(1))
        #expect(session.timer == .running(endsAt: start + .seconds(180)))
    }

    @Test func emptyRecipeHasNoStepAndNoTimer() {
        var session = CookingSession(
            recipe: Recipe(
                id: "empty", name: "Leer", tag: "", baseServings: 2, totalMinutes: 0, ingredients: [], steps: []))
        #expect(session.currentStep == nil)
        #expect(session.timer == .none)
        session.send(.next)
        session.send(.startTimer(at: start))
        #expect(session.stepIndex == 0)
        #expect(session.timer == .none)
    }

    @Test func startsWithRequestedServingsClamped() {
        #expect(CookingSession(recipe: recipe, servings: 5).servings == 5)
        #expect(CookingSession(recipe: recipe, servings: 40).servings == 8)
    }

    @Test func listsIngredientsPerStep() {
        let session = CookingSession(recipe: recipe, servings: 6)
        #expect(
            session.ingredients(for: recipe.steps[0]).map(\.amount) == [.measured(400, .gram), .measured(1, .piece)])
        #expect(session.ingredients(for: recipe.steps[1]).isEmpty)
    }
}
