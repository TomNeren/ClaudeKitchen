import ActivityKit
import KitchenCore

/// Starts, updates and ends the step Live Activity for one guided cook.
///
/// `Activity` is not `Sendable`, so only its id is kept and the activity is looked up off the main actor for each
/// async call. Calls are chained, so the Lock Screen never shows an older step than the app.
@MainActor
final class CookingLiveActivity {
    private typealias GuideActivity = Activity<CookingActivityAttributes>

    private var activityID: String?
    private var lastState: CookingActivityAttributes.ContentState?
    private var pending: Task<Void, Never>?

    /// Shows `session` on the Lock Screen, starting the activity on first use. Unchanged states are skipped.
    func show(_ session: CookingSession) {
        guard let state = Self.state(for: session), state != lastState else { return }
        lastState = state
        let content = ActivityContent(state: state, staleDate: nil)
        if let activityID {
            enqueue { await Self.update(activityID, with: content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            // Activities left by an earlier run (for example after the app was killed) would show dead buttons.
            let leftovers = GuideActivity.activities.map(\.id)
            enqueue { await Self.end(leftovers) }
            activityID = try? GuideActivity.request(
                attributes: CookingActivityAttributes(recipeName: session.recipe.name), content: content
            ).id
        }
    }

    func end() {
        guard let activityID else { return }
        self.activityID = nil
        lastState = nil
        enqueue { await Self.end([activityID]) }
    }

    /// Waits until every update handed over so far has reached the system.
    func flush() async {
        await pending?.value
    }

    private func enqueue(_ work: @escaping @Sendable () async -> Void) {
        let previous = pending
        pending = Task {
            await previous?.value
            await work()
        }
    }

    @concurrent
    private nonisolated static func update(
        _ id: String, with content: ActivityContent<CookingActivityAttributes.ContentState>
    ) async {
        await GuideActivity.activities.first { $0.id == id }?.update(content)
    }

    @concurrent
    private nonisolated static func end(_ ids: [String]) async {
        for activity in GuideActivity.activities where ids.contains(activity.id) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    static func state(for session: CookingSession) -> CookingActivityAttributes.ContentState? {
        guard let step = session.currentStep else { return nil }
        return CookingActivityAttributes.ContentState(
            stepNumber: session.stepIndex + 1, totalSteps: session.recipe.steps.count, phase: step.phase,
            text: step.text,
            settingText: step.setting.map { SettingFormatter.parts(of: $0).joined(separator: " · ") } ?? "",
            isFirstStep: session.isFirstStep, isLastStep: session.isLastStep)
    }
}
