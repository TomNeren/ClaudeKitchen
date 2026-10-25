import ActivityKit
import AppIntents
import KitchenCore
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island view of the current cooking step, with buttons to move between steps.
struct CookingGuideActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CookingActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(context.attributes.recipeName)
                        .font(.headline)
                    Spacer()
                    Text("Schritt \(context.state.stepNumber) von \(context.state.totalSteps)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(context.state.text)
                    .font(.body)
                    .lineLimit(2)
                if !context.state.settingText.isEmpty {
                    Text(context.state.settingText)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                StepButtons(state: context.state)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(context.state.stepNumber)/\(context.state.totalSteps)")
                        .font(.headline)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.phase)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if !context.state.settingText.isEmpty {
                            Text(context.state.settingText)
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                        StepButtons(state: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: "fork.knife")
            } compactTrailing: {
                Text("\(context.state.stepNumber)/\(context.state.totalSteps)")
                    .monospacedDigit()
            } minimal: {
                Text("\(context.state.stepNumber)")
                    .monospacedDigit()
            }
        }
    }
}

private struct StepButtons: View {
    let state: CookingActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Button(intent: PreviousStepIntent()) {
                Label("Zurück", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .disabled(state.isFirstStep)
            Button(intent: NextStepIntent()) {
                Label("Weiter", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .disabled(state.isLastStep)
        }
        .font(.headline)
        .buttonStyle(.bordered)
    }
}

// Previews use the bundled recipes through the same state builder as the app.
private enum PreviewStates {
    static let recipe = Recipe.fixtures.first { $0.id == "zitronen-linsen-eintopf" } ?? Recipe.fixtures[0]
    static let attributes = CookingActivityAttributes(recipeName: recipe.name)

    static func state(atStep index: Int) -> CookingActivityAttributes.ContentState {
        var session = CookingSession(recipe: recipe)
        session.send(.goToStep(index))
        return CookingActivityAttributes.ContentState(session: session)!
    }

    static var first: CookingActivityAttributes.ContentState { state(atStep: 0) }
    /// A step without a device setting (adding ingredients).
    static var withoutSetting: CookingActivityAttributes.ContentState { state(atStep: 2) }
    static var simmering: CookingActivityAttributes.ContentState { state(atStep: 3) }
    static var last: CookingActivityAttributes.ContentState { state(atStep: recipe.steps.count - 1) }
}

#Preview("Sperrbildschirm", as: .content, using: PreviewStates.attributes) {
    CookingGuideActivity()
} contentStates: {
    PreviewStates.first
    PreviewStates.withoutSetting
    PreviewStates.simmering
    PreviewStates.last
}

#Preview("Dynamic Island", as: .dynamicIsland(.expanded), using: PreviewStates.attributes) {
    CookingGuideActivity()
} contentStates: {
    PreviewStates.simmering
    PreviewStates.last
}

#Preview("Kompakt", as: .dynamicIsland(.compact), using: PreviewStates.attributes) {
    CookingGuideActivity()
} contentStates: {
    PreviewStates.simmering
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: PreviewStates.attributes) {
    CookingGuideActivity()
} contentStates: {
    PreviewStates.simmering
}
