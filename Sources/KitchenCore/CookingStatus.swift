import Foundation

/// Where the cook stands, as values. The app phrases it for Siri and the voice mode.
public struct CookingStatus: Sendable, Equatable {
    public enum Timer: Sendable, Equatable {
        /// The step has no timer, or it has not been started.
        case none
        case running(remaining: Duration)
        case paused(remaining: Duration)
        /// Ran out, including a timer that is past its end but has not been ticked yet.
        case finished
    }

    public var stepNumber: Int
    public var totalSteps: Int
    public var phase: String
    public var text: String
    public var setting: DeviceSetting?
    public var timer: Timer
}

extension CookingSession {
    /// The status at `now`. Nil only for a recipe without steps.
    public func status(at now: ContinuousClock.Instant) -> CookingStatus? {
        guard let step = currentStep else { return nil }
        let timerStatus: CookingStatus.Timer
        switch timer {
        case .none, .ready:
            timerStatus = .none
        case .finished:
            timerStatus = .finished
        case .paused(let remaining):
            timerStatus = .paused(remaining: remaining)
        case .running(let endsAt):
            let remaining = now.duration(to: endsAt)
            timerStatus = remaining > .zero ? .running(remaining: remaining) : .finished
        }
        return CookingStatus(
            stepNumber: stepIndex + 1, totalSteps: recipe.steps.count, phase: step.phase, text: step.text,
            setting: step.setting, timer: timerStatus)
    }
}
