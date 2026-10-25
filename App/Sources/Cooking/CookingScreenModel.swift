import KitchenCore
import Observation

/// Drives one guided cook: forwards intents to the `CookingSession` and feeds it time while a timer runs.
@MainActor @Observable
final class CookingScreenModel {
    private(set) var session: CookingSession
    /// The instant the countdown was last shown for. Only advances while a timer runs, so idle steps never redraw.
    private(set) var now: ContinuousClock.Instant

    private let clock = ContinuousClock()

    init(recipe: Recipe, servings: Int, profile: DeviceProfile = .omniCook) {
        session = CookingSession(recipe: recipe, servings: servings, servingsRange: profile.servingsRange(for: recipe))
        now = clock.now
    }

    var remaining: Duration? { session.timer.remaining(at: now) }

    func next() { send(.next) }
    func previous() { send(.previous) }
    func goToStep(_ index: Int) { send(.goToStep(index)) }
    func startTimer() { send(.startTimer(at: clock.now)) }
    func pauseTimer() { send(.pauseTimer(at: clock.now)) }
    func resetTimer() { send(.resetTimer) }

    /// Re-reads the clock. Does nothing unless a timer runs.
    func tick() {
        guard session.isTimerRunning else { return }
        now = clock.now
        session.send(.tick(now))
    }

    /// Ticks four times a second while a timer runs and idles otherwise. Cancelled with the view's `.task`.
    func runClock() async {
        while !Task.isCancelled {
            tick()
            try? await Task.sleep(for: .milliseconds(250), clock: clock)
        }
    }

    private func send(_ action: CookingAction) {
        session.send(action)
        now = clock.now
    }
}
