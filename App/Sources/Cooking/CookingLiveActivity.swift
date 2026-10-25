import ActivityKit
import KitchenCore

/// Starts, updates and ends the step Live Activity for one guided cook.
///
/// `Activity` is not `Sendable`, so only its id is kept and the activity is looked up fresh for each async call.
@MainActor
final class CookingLiveActivity {
    private typealias GuideActivity = Activity<CookingActivityAttributes>

    private var activityID: String?
    private var lastState: CookingActivityAttributes.ContentState?

    /// Shows `session` on the Lock Screen, starting the activity on first use. Unchanged states are skipped.
    func show(_ session: CookingSession) {
        guard let state = Self.state(for: session), state != lastState else { return }
        lastState = state
        let content = ActivityContent(state: state, staleDate: nil)
        if let activityID {
            Task {
                await GuideActivity.activities.first { $0.id == activityID }?.update(content)
            }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            activityID = try? GuideActivity.request(
                attributes: CookingActivityAttributes(recipeName: session.recipe.name), content: content
            ).id
        }
    }

    func end() {
        guard let activityID else { return }
        self.activityID = nil
        lastState = nil
        Task {
            await GuideActivity.activities.first { $0.id == activityID }?.end(nil, dismissalPolicy: .immediate)
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
