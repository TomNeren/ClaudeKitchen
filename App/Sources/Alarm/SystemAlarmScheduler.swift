import AlarmKit
import Foundation
import KitchenCore
import SwiftUI

/// Holds the cooking timer as an AlarmKit countdown, so it rings in the background and on silent.
///
/// One instance for the whole app: the app only ever has one cooking timer, so every alarm AlarmKit holds for this
/// app that is not the current one is stale and gets cancelled. Pause is a cancel and resume a fresh schedule,
/// which keeps the adapter independent of AlarmKit's own pause state.
/// `AlarmManager` is not `Sendable`, so it is read from `AlarmManager.shared` at each call instead of being stored.
actor SystemAlarmScheduler: AlarmScheduler {
    static let shared = SystemAlarmScheduler()

    /// The alarm scheduled for the current running timer, and the instant it was scheduled for.
    private var current: (id: Alarm.ID, endsAt: ContinuousClock.Instant)?

    func apply(_ alarm: TimerAlarm?) async {
        switch alarm?.phase {
        case .finished:
            // Ringing until the cook stops it; nothing to change.
            return
        case .running(let endsAt):
            guard current?.endsAt != endsAt, let alarm else { return }
            cancelAll()
            await schedule(alarm, endsAt: endsAt)
        case .paused, nil:
            cancelAll()
        }
    }

    private func schedule(_ alarm: TimerAlarm, endsAt: ContinuousClock.Instant) async {
        guard await isAuthorized() else { return }
        // Measured after a possible permission prompt, so the system alarm fires with the in-app timer.
        let seconds = max(1, ContinuousClock.now.duration(to: endsAt) / .seconds(1))
        let id = UUID()
        let configuration = AlarmManager.AlarmConfiguration<CookingAlarmData>.timer(
            duration: seconds, attributes: Self.attributes(for: alarm))
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            current = (id, endsAt)
        } catch {
            current = nil
        }
    }

    private func cancelAll() {
        let ids = ((try? AlarmManager.shared.alarms) ?? []).map(\.id)
        for id in ids {
            try? AlarmManager.shared.cancel(id: id)
        }
        current = nil
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
        let presentation = AlarmPresentation(
            alert: AlarmPresentation.Alert(title: "\(alarm.stepPhase) ist fertig"),
            countdown: AlarmPresentation.Countdown(title: "\(alarm.recipeName): \(alarm.stepPhase)"))
        return AlarmAttributes(
            presentation: presentation,
            metadata: CookingAlarmData(
                recipeName: alarm.recipeName, stepNumber: alarm.stepNumber, stepPhase: alarm.stepPhase),
            tintColor: Palette.accent)
    }
}

/// For previews: never touches the system.
struct NoAlarmScheduler: AlarmScheduler {
    func apply(_ alarm: TimerAlarm?) async {}
}
