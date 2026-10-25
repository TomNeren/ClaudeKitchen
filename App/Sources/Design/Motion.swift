import SwiftUI

/// Named motion tokens. Views use these instead of literal animation values.
/// Values are first-pass presets; tune them on device (see app-architecture, section 6).
enum Motion {
    /// Servings stepper value change.
    static let servings: Animation = .snappy(duration: 0.25)
    /// Search results appearing and disappearing.
    static let searchResults: Animation = .smooth(duration: 0.3)
}
