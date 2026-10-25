import SwiftUI

/// Named motion tokens. Views use these instead of literal animation values.
/// Values are first-pass presets; tune them on device (see app-architecture, section 6).
enum Motion {
    /// Servings stepper value change.
    static let servings: Animation = .snappy(duration: 0.25)
    /// Search results appearing and disappearing.
    static let searchResults: Animation = .smooth(duration: 0.3)
    /// Moving between steps in the cooking mode.
    static let stepAdvance: Animation = .smooth(duration: 0.35)
    /// Step change with Reduce Motion: a cross-fade instead of travel, same timing.
    static let stepCrossFade: Animation = .easeInOut(duration: 0.35)
    /// Countdown digits rolling once a second.
    static let timerTick: Animation = .snappy(duration: 0.2)
}
