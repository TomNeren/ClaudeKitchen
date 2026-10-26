import SwiftUI

/// Named motion tokens. Views use these instead of literal animation values.
///
/// Values follow the apple-motion-feel rule "bounce is earned by momentum": everything here is tap-driven, so it is
/// critically damped (`bounce: 0`). The step pager's swipe is momentum-driven but animated by the system pager.
/// Re-check each value on an iPhone at 120 Hz (device checklist in PLAN.md).
enum Motion {
    /// Servings stepper value change: small, tap-driven.
    static let servings: Animation = .spring(duration: 0.3, bounce: 0)
    /// Search results appearing and disappearing: repositioning cards.
    static let searchResults: Animation = .spring(duration: 0.4, bounce: 0)
    /// Moving between steps with the Weiter and Zurück buttons: a move, tap-driven.
    static let stepAdvance: Animation = .spring(duration: 0.4, bounce: 0)
    /// Step change with Reduce Motion: a cross-fade instead of travel, same timing.
    static let stepCrossFade: Animation = .easeInOut(duration: 0.4)
    /// Countdown digits rolling once a second: must settle well inside the second.
    static let timerTick: Animation = .spring(duration: 0.25, bounce: 0)
    /// Switching between the original and a health variant: rows appear and move, tap-driven. The inserted
    /// rows fade in, so the same token works with Reduce Motion.
    static let variantChange: Animation = .spring(duration: 0.35, bounce: 0)
    /// The voice status pill: appears, changes text and disappears as a fade, so it never pulls the eye from the step.
    static let voiceStatus: Animation = .easeInOut(duration: 0.3)
}
