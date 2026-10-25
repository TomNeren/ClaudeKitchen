import Foundation

/// State of the timer of the current step. A running timer stores its end instant, never a countdown, so it stays
/// correct when the app is suspended.
public enum TimerState: Sendable, Equatable {
    /// The step has no timer.
    case none
    case ready(Duration)
    case running(endsAt: ContinuousClock.Instant)
    case paused(remaining: Duration)
    case finished

    /// Time left at `now`, or nil when the step has no timer.
    public func remaining(at now: ContinuousClock.Instant) -> Duration? {
        switch self {
        case .none:
            return nil
        case .ready(let duration):
            return duration
        case .running(let endsAt):
            return max(.zero, now.duration(to: endsAt))
        case .paused(let remaining):
            return remaining
        case .finished:
            return .zero
        }
    }
}

/// Everything the cook can do during a guided cook. Time always comes in from outside, so tests never sleep.
public enum CookingAction: Sendable, Equatable {
    case next
    case previous
    case goToStep(Int)
    case setServings(Int)
    case startTimer(at: ContinuousClock.Instant)
    case pauseTimer(at: ContinuousClock.Instant)
    case resetTimer
    case tick(ContinuousClock.Instant)
}

/// The guided cook as a state machine. Every change goes through `send(_:)`.
public struct CookingSession: Sendable, Equatable {
    /// Servings the app offers unless a screen narrows them further, for example to stay below the fill mark.
    public static let defaultServingsRange = 1...8

    public let recipe: Recipe
    public let servingsRange: ClosedRange<Int>
    public private(set) var stepIndex: Int
    public private(set) var servings: Int
    public private(set) var timer: TimerState
    /// The step the timer belongs to. A running or paused timer keeps going when the cook moves to another step,
    /// so a stray swipe never throws away a countdown.
    public private(set) var timerStepIndex: Int
    /// How many timers have run out so far. The UI plays its feedback when this changes.
    public private(set) var finishedTimerCount: Int

    /// Starts at the first step with `servings` (the recipe's base servings by default), clamped to `servingsRange`.
    public init(
        recipe: Recipe, servings: Int? = nil, servingsRange: ClosedRange<Int> = CookingSession.defaultServingsRange
    ) {
        self.recipe = recipe
        self.servingsRange = servingsRange
        stepIndex = 0
        self.servings = min(max(servings ?? recipe.baseServings, servingsRange.lowerBound), servingsRange.upperBound)
        timer = Self.initialTimer(for: recipe.steps.first)
        timerStepIndex = 0
        finishedTimerCount = 0
    }

    public var currentStep: Step? {
        recipe.steps.indices.contains(stepIndex) ? recipe.steps[stepIndex] : nil
    }

    public var isFirstStep: Bool { stepIndex == 0 }
    public var isLastStep: Bool { stepIndex >= recipe.steps.count - 1 }

    /// True while a timer from an earlier or later step is still running or paused on the current step.
    public var isTimerFromOtherStep: Bool { timerStepIndex != stepIndex }

    public var isTimerRunning: Bool {
        if case .running = timer { true } else { false }
    }

    /// Ingredients that go in at `step`, with their amounts for the current servings.
    public func ingredients(for step: Step) -> [(ingredient: Ingredient, amount: Amount)] {
        step.ingredientIDs.compactMap { id in
            recipe.ingredient(id).map { ($0, $0.amount(from: recipe.baseServings, to: servings)) }
        }
    }

    /// Ingredients with their amounts for the current servings.
    public var scaledIngredients: [(ingredient: Ingredient, amount: Amount)] {
        recipe.ingredients.map { ($0, $0.amount(from: recipe.baseServings, to: servings)) }
    }

    public mutating func send(_ action: CookingAction) {
        switch action {
        case .next:
            move(to: stepIndex + 1)
        case .previous:
            move(to: stepIndex - 1)
        case .goToStep(let index):
            move(to: index)
        case .setServings(let value):
            servings = min(max(value, servingsRange.lowerBound), servingsRange.upperBound)
        case .startTimer(let now):
            switch timer {
            case .ready(let duration), .paused(let duration):
                timer = .running(endsAt: now.advanced(by: duration))
            case .none, .running, .finished:
                break
            }
        case .pauseTimer(let now):
            if case .running(let endsAt) = timer {
                let remaining = now.duration(to: endsAt)
                if remaining > .zero {
                    timer = .paused(remaining: remaining)
                } else {
                    finishTimer()
                }
            }
        case .resetTimer:
            loadTimer(for: stepIndex)
        case .tick(let now):
            if case .running(let endsAt) = timer, now >= endsAt {
                finishTimer()
            }
        }
    }

    /// Moves to `index`; out-of-range targets are ignored. A running or paused timer stays; otherwise the new step's
    /// timer is loaded.
    private mutating func move(to index: Int) {
        guard recipe.steps.indices.contains(index), index != stepIndex else { return }
        stepIndex = index
        switch timer {
        case .running, .paused:
            break
        case .none, .ready, .finished:
            loadTimer(for: index)
        }
    }

    private mutating func loadTimer(for index: Int) {
        timerStepIndex = index
        timer = Self.initialTimer(for: recipe.steps.indices.contains(index) ? recipe.steps[index] : nil)
    }

    private mutating func finishTimer() {
        timer = .finished
        finishedTimerCount += 1
    }

    private static func initialTimer(for step: Step?) -> TimerState {
        step?.timerDuration.map { .ready($0) } ?? TimerState.none
    }
}
