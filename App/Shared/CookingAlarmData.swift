import AlarmKit

/// What the system alarm carries for its Live Activity: which recipe and step the timer belongs to.
/// Compiled into both the app and the widget extension.
nonisolated struct CookingAlarmData: AlarmMetadata {
    var recipeName: String
    var stepNumber: Int
    var stepPhase: String
}
