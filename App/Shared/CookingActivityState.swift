import KitchenCore

extension CookingActivityAttributes.ContentState {
    /// The Lock Screen state for `session`, nil for a recipe without steps. Shared by the app and the widget previews,
    /// so previews show exactly what the app sends.
    init?(session: CookingSession) {
        guard let step = session.currentStep else { return nil }
        self.init(
            stepNumber: session.stepIndex + 1, totalSteps: session.recipe.steps.count, phase: step.phase,
            text: step.text,
            settingText: step.setting.map { SettingFormatter.parts(of: $0).joined(separator: " · ") } ?? "",
            isFirstStep: session.isFirstStep, isLastStep: session.isLastStep)
    }
}
