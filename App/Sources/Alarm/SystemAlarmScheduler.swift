import AlarmKit
import Foundation
import KitchenCore
import SwiftUI

/// Holds the cooking timer as an AlarmKit countdown, so it rings in the background and on silent.
/// `AlarmManager` is not `Sendable`, so it is read from `AlarmManager.shared` at each call instead of being stored.
actor SystemAlarmScheduler: AlarmScheduler {
    private var current: (id: Alarm.ID, firesAt: Date, isPaused: Bool)?

    func apply(_ alarm: TimerAlarm?) async {
        guard let alarm else {
            // A timer that already ran out keeps ringing until the cook stops it; anything earlier is cancelled.
            if let current, current.isPaused || current.firesAt > .now {
                try? AlarmManager.shared.cancel(id: current.id)
            }
            current = nil
            return
        }
        switch alarm.phase {
        case .paused:
            if let current, !current.isPaused {
                try? AlarmManager.shared.pause(id: current.id)
                self.current?.isPaused = true
            }
        case .running(let endsAt):
            let remaining = ContinuousClock.now.duration(to: endsAt)
            let seconds = max(1, Double(remaining.components.seconds) + Double(remaining.components.attoseconds) / 1e18)
            let firesAt = Date.now.addingTimeInterval(seconds)
            if let current, current.isPaused {
                try? AlarmManager.shared.resume(id: current.id)
                self.current = (current.id, firesAt, false)
                return
            }
            if let current, abs(current.firesAt.timeIntervalSince(firesAt)) < 1 {
                return
            }
            if let current {
                try? AlarmManager.shared.cancel(id: current.id)
            }
            await schedule(alarm, after: seconds, firesAt: firesAt)
        }
    }

    private func schedule(_ alarm: TimerAlarm, after seconds: TimeInterval, firesAt: Date) async {
        guard await isAuthorized() else {
            current = nil
            return
        }
        let id = UUID()
        let configuration = AlarmManager.AlarmConfiguration<CookingAlarmData>.timer(
            duration: seconds, attributes: Self.attributes(for: alarm))
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            current = (id, firesAt, false)
        } catch {
            current = nil
        }
    }

    private func isAuthorized() async -> Bool {
        switch AlarmManager.shared.authorizationState {
        case .authorized:
            return true
        case .notDetermined:
            return (try? await AlarmManager.shared.requestAuthorization()) == .authorized
        default:
            return false
        }
    }

    private static func attributes(for alarm: TimerAlarm) -> AlarmAttributes<CookingAlarmData> {
        let stop = AlarmButton(text: "Stopp", textColor: .white, systemImageName: "stop.fill")
        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(title: "\(alarm.stepPhase) ist fertig", stopButton: stop),
            countdown: AlarmPresentation.Countdown(title: "\(alarm.recipeName): \(alarm.stepPhase)"))
        return AlarmAttributes(
            presentation: presentation,
            metadata: CookingAlarmData(
                recipeName: alarm.recipeName, stepNumber: alarm.stepNumber, stepPhase: alarm.stepPhase),
            tintColor: Palette.accent)
    }
}
