import Foundation

/// The alarm the system should hold for the cooking session's timer, so the cook hears it with the app in the
/// background or the phone on silent. The app layer turns this into a system alarm.
public struct TimerAlarm: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case running(endsAt: ContinuousClock.Instant)
        case paused(remaining: Duration)
    }

    public var phase: Phase
    /// Recipe name, shown as the alarm's title.
    public var recipeName: String
    /// One-based number of the step the timer belongs to.
    public var stepNumber: Int
    /// Phase label of that step, for example "Köcheln".
    public var stepPhase: String
    /// The timer's full length, for the countdown display.
    public var totalDuration: Duration
}

/// Where the system alarm lives. Implemented in the app with AlarmKit; tests use a recorder.
public protocol AlarmScheduler: Sendable {
    /// Makes the system hold exactly `alarm`, replacing or removing any earlier one.
    func apply(_ alarm: TimerAlarm?) async
}

extension CookingSession {
    /// The alarm that matches the current timer: one while it runs or is paused, none otherwise.
    public var alarm: TimerAlarm? {
        let phase: TimerAlarm.Phase
        switch timer {
        case .running(let endsAt):
            phase = .running(endsAt: endsAt)
        case .paused(let remaining):
            phase = .paused(remaining: remaining)
        case .none, .ready, .finished:
            return nil
        }
        guard recipe.steps.indices.contains(timerStepIndex) else { return nil }
        let step = recipe.steps[timerStepIndex]
        return TimerAlarm(
            phase: phase, recipeName: recipe.name, stepNumber: timerStepIndex + 1, stepPhase: step.phase,
            totalDuration: step.timerDuration ?? .zero)
    }
}
