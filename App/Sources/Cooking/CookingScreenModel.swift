import KitchenCore
import Observation

/// Drives one guided cook: forwards intents to the `CookingSession` and feeds it time while a timer runs.
@MainActor @Observable
final class CookingScreenModel {
    private(set) var session: CookingSession
    /// The instant the countdown was last shown for. Only advances while a timer runs, so idle steps never redraw.
    private(set) var now: ContinuousClock.Instant

    private let clock = ContinuousClock()
    private let alarms: any AlarmScheduler
    /// Last alarm handed to the scheduler, and the chain of pending hand-overs so they apply in order.
    private var appliedAlarm: TimerAlarm?
    private var alarmUpdate: Task<Void, Never>?
    private let liveActivity = CookingLiveActivity()

    init(
        recipe: Recipe, servings: Int, profile: DeviceProfile = .omniCook,
        alarms: any AlarmScheduler = SystemAlarmScheduler.shared
    ) {
        session = CookingSession(recipe: recipe, servings: servings, servingsRange: profile.servingsRange(for: recipe))
        now = clock.now
        self.alarms = alarms
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
        let finished = session.finishedTimerCount
        session.send(.tick(now))
        if session.finishedTimerCount != finished {
            syncAlarm()
        }
    }

    /// Entering the cooking mode: shows the step Live Activity and lets Siri and the activity's buttons reach this
    /// cook.
    func begin() {
        CookingIntentBridge.current = self
        liveActivity.show(session)
    }

    /// Leaving the cooking mode ends the Live Activity and removes the timer, unless it already rang: then it rings
    /// until the cook stops it.
    func end() {
        if CookingIntentBridge.current === self {
            CookingIntentBridge.current = nil
        }
        liveActivity.end()
        if case .finished = session.alarm?.phase { return }
        appliedAlarm = nil
        let previous = alarmUpdate
        let alarms = self.alarms
        alarmUpdate = Task {
            await previous?.value
            await alarms.apply(nil)
        }
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
        syncAlarm()
        liveActivity.show(session)
    }

    /// Hands the session's alarm to the system whenever it changes, one hand-over after the other.
    private func syncAlarm() {
        let alarm = session.alarm
        guard alarm != appliedAlarm else { return }
        appliedAlarm = alarm
        let previous = alarmUpdate
        let alarms = self.alarms
        alarmUpdate = Task {
            await previous?.value
            await alarms.apply(alarm)
        }
    }
}

extension CookingScreenModel: CookingIntentTarget {
    func perform(_ command: CookingIntentCommand) async -> String {
        // The app may have been suspended: catch up first, so a timer that ran out counts as finished.
        tick()
        let answer: String
        switch command {
        case .next:
            if session.isLastStep {
                answer = "Das ist schon der letzte Schritt."
            } else {
                next()
                answer = stepAnswer
            }
        case .previous:
            if session.isFirstStep {
                answer = "Das ist schon der erste Schritt."
            } else {
                previous()
                answer = stepAnswer
            }
        case .startTimer:
            switch session.timer {
            case .ready, .paused:
                startTimer()
                answer = "Timer läuft. \(remainingAnswer)"
            case .running:
                answer = "Der Timer läuft schon. \(remainingAnswer)"
            case .finished:
                answer = "Der Timer ist abgelaufen."
            case .none:
                answer = "Dieser Schritt hat keinen Timer."
            }
        case .pauseTimer:
            if session.isTimerRunning {
                pauseTimer()
                answer = "Timer pausiert. \(remainingAnswer)"
            } else {
                answer = "Gerade läuft kein Timer."
            }
        case .currentStep:
            answer = stepAnswer
        case .remainingTime:
            answer = remainingAnswer
        }
        await alarmUpdate?.value
        await liveActivity.flush()
        return answer
    }

    private var stepAnswer: String {
        session.status(at: clock.now).map(CookingAnswers.step) ?? "Dieses Rezept hat keine Schritte."
    }

    private var remainingAnswer: String {
        session.status(at: clock.now).map(CookingAnswers.remainingTime) ?? "Gerade läuft kein Timer."
    }
}
