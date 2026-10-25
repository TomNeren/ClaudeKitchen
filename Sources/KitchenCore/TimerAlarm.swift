import Foundation

/// The alarm the system should hold for the cooking session's timer, so the cook hears it with the app in the
/// background or the phone on silent. The app layer turns this into a system alarm.
public struct TimerAlarm: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        /// Counting down to `endsAt`: the system alarm must be scheduled for that instant.
        case running(endsAt: ContinuousClock.Instant)
        /// Paused: the system alarm must not ring.
        case paused
        /// Ran out: the system alarm rings and keeps ringing until the cook stops it, so leave it alone.
        case finished
    }

    public var phase: Phase
    /// Recipe name, shown as the alarm's title.
    public var recipeName: String
    /// One-based number of the step the timer belongs to.
    public var stepNumber: Int
    /// Phase label of that step, for example "Köcheln".
    public var stepPhase: String
}

/// Where the system alarm lives. Implemented in the app with AlarmKit; previews use a no-op.
public protocol AlarmScheduler: Sendable {
    /// Makes the system hold what `alarm` describes. `nil` means no timer: remove any alarm, ringing or not.
    func apply(_ alarm: TimerAlarm?) async
}

extension CookingSession {
    /// The alarm that matches the current timer, or nil when there is no timer to alarm for.
    public var alarm: TimerAlarm? {
        let phase: TimerAlarm.Phase
        switch timer {
        case .running(let endsAt):
            phase = .running(endsAt: endsAt)
        case .paused:
            phase = .paused
        case .finished:
            phase = .finished
        case .none, .ready:
            return nil
        }
        guard recipe.steps.indices.contains(timerStepIndex) else { return nil }
        return TimerAlarm(
            phase: phase, recipeName: recipe.name, stepNumber: timerStepIndex + 1,
            stepPhase: recipe.steps[timerStepIndex].phase)
    }
}
