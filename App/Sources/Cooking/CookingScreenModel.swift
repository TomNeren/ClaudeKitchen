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
        CookingIntentBridge.handler = { [weak self] command in self?.handle(command) }
        CookingQuestions.currentStep = { [weak self] in
            self.map { CookingAnswers.currentStep(of: $0.session) } ?? CurrentStepIntent.noCooking
        }
        CookingQuestions.remainingTime = { [weak self] in
            self.map { CookingAnswers.remainingTime(of: $0.session, at: $0.clock.now) } ?? CurrentStepIntent.noCooking
        }
        liveActivity.show(session)
    }

    /// Leaving the cooking mode ends the Live Activity and removes the timer, unless it already rang: then it rings
    /// until the cook stops it.
    func end() {
        CookingIntentBridge.handler = nil
        CookingQuestions.currentStep = nil
        CookingQuestions.remainingTime = nil
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

    private func handle(_ command: CookingIntentCommand) {
        switch command {
        case .next: next()
        case .previous: previous()
        case .startTimer: startTimer()
        case .pauseTimer: pauseTimer()
        }
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
