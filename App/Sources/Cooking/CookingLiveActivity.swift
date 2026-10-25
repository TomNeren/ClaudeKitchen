import ActivityKit
import KitchenCore

/// Starts, updates and ends the step Live Activity for one guided cook.
@MainActor
final class CookingLiveActivity {
    private var activity: Activity<CookingActivityAttributes>?
    private var lastState: CookingActivityAttributes.ContentState?

    /// Shows `session` on the Lock Screen, starting the activity on first use. Unchanged states are skipped.
    func show(_ session: CookingSession) {
        guard let state = Self.state(for: session), state != lastState else { return }
        lastState = state
        let content = ActivityContent(state: state, staleDate: nil)
        if let activity {
            Task { await activity.update(content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            activity = try? Activity.request(
                attributes: CookingActivityAttributes(recipeName: session.recipe.name), content: content)
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        lastState = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
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
