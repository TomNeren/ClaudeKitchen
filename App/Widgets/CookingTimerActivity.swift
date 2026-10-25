import AlarmKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island presentation of the cooking timer that AlarmKit counts down.
struct CookingTimerActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<CookingAlarmData>.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "frying.pan.fill")
                    .font(.title)
                    .foregroundStyle(context.attributes.tintColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.metadata?.recipeName ?? "Omni Cook")
                        .font(.headline)
                    Text(stepLine(context.attributes.metadata))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                CountdownText(mode: context.state.mode)
                    .font(.system(.title, design: .serif, weight: .semibold))
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "frying.pan.fill")
                        .foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(mode: context.state.mode)
                        .font(.title2.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(stepLine(context.attributes.metadata))
                        .font(.subheadline)
                }
            } compactLeading: {
                Image(systemName: "frying.pan.fill")
                    .foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                CountdownText(mode: context.state.mode)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(context.attributes.tintColor)
            }
        }
    }

    private func stepLine(_ metadata: CookingAlarmData?) -> String {
        guard let metadata else { return "Timer" }
        return "Schritt \(metadata.stepNumber): \(metadata.stepPhase)"
    }
}

/// Counts down to the fire date while running; shows a static label when paused or ringing.
private struct CountdownText: View {
    let mode: AlarmPresentationState.Mode

    var body: some View {
        switch mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...countdown.fireDate, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        case .paused:
            Text("Pause")
        case .alert:
            Text("Fertig")
        @unknown default:
            Text("Timer")
        }
    }
}
