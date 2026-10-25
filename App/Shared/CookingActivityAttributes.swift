import ActivityKit

/// Live Activity for the guided cook: which step is up and what to set. The timer countdown itself is the AlarmKit
/// activity, so this one stays about the step.
struct CookingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stepNumber: Int
        var totalSteps: Int
        var phase: String
        var text: String
        /// Device setting as one line, for example "120 °C · Linkslauf 1 · 3 Min". Empty when nothing to set.
        var settingText: String
        var isFirstStep: Bool
        var isLastStep: Bool
    }

    var recipeName: String
}
