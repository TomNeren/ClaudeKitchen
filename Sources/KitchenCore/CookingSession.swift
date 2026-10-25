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

    /// Starts at the first step with the recipe's base servings, clamped to `servingsRange`.
    public init(recipe: Recipe, servingsRange: ClosedRange<Int> = CookingSession.defaultServingsRange) {
        self.recipe = recipe
        self.servingsRange = servingsRange
        stepIndex = 0
        servings = min(max(recipe.baseServings, servingsRange.lowerBound), servingsRange.upperBound)
        timer = Self.initialTimer(for: recipe.steps.first)
    }

    public var currentStep: Step? {
        recipe.steps.indices.contains(stepIndex) ? recipe.steps[stepIndex] : nil
    }

    public var isFirstStep: Bool { stepIndex == 0 }
    public var isLastStep: Bool { stepIndex >= recipe.steps.count - 1 }

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
                timer = remaining > .zero ? .paused(remaining: remaining) : .finished
            }
        case .resetTimer:
            timer = Self.initialTimer(for: currentStep)
        case .tick(let now):
            if case .running(let endsAt) = timer, now >= endsAt {
                timer = .finished
            }
        }
    }

    /// Changing the step replaces the timer with the new step's timer. Out-of-range targets are ignored.
    private mutating func move(to index: Int) {
        guard recipe.steps.indices.contains(index), index != stepIndex else { return }
        stepIndex = index
        timer = Self.initialTimer(for: currentStep)
    }

    private static func initialTimer(for step: Step?) -> TimerState {
        step?.timerDuration.map { .ready($0) } ?? TimerState.none
    }
}
