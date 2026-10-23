---
name: app-architecture
description: Architecture rules for ClaudeKitchen, a Swift 6 iOS/iPadOS cooking app with guided step-by-step cooking for a multicooker. Use before adding a feature, a new type, a module, a dependency, persistence, networking, a timer or any background work; when deciding where code belongs (KitchenCore package vs. app target); when writing @Observable models, view models or SwiftUI screens; when touching concurrency, actors, Sendable or @MainActor; when writing tests; and when reviewing a change for structure. Also covers iOS-specific SwiftUI patterns that the swiftui-macos skill does not.
---

# ClaudeKitchen architecture

The app guides a cook through a recipe one step at a time. Each step can carry device settings (temperature, speed, reverse rotation, time) and a timer. The recipe list, the step flow, the timer and the portion scaling are the product. Everything else serves them.

## 1. Two layers, one hard boundary

```
ClaudeKitchen/
├── Package.swift            KitchenCore, platform-neutral, builds on Linux
├── Sources/KitchenCore/     domain + use cases, no UI, no Apple-only frameworks
├── Tests/KitchenCoreTests/  Swift Testing, runs in the cloud container
└── App/                     Xcode project, SwiftUI only, built on a Mac
```

**KitchenCore** holds everything that can be decided without a screen:
- Domain types: `Recipe`, `Ingredient`, `Step`, `DeviceSetting`, `Quantity`, `Servings`.
- Rules: portion scaling, unit formatting, step navigation, timer state.
- Ports (protocols) for anything the outside world provides: `RecipeStore`, `Clock`, `AlarmScheduler`.
- Bundled recipe data as JSON resources.

**App** holds only what needs Apple frameworks: SwiftUI views, `@Observable` screen models, SwiftData or file persistence, notifications, haptics, Live Activities, Liquid Glass.

**The rule:** KitchenCore imports `Foundation` and nothing else. No `SwiftUI`, `UIKit`, `SwiftData`, `UserNotifications`, `ActivityKit`, `Combine`. If a type needs one of those, it belongs in App, or KitchenCore defines a protocol and App implements it. This is what lets the cloud container build and test the logic, because Linux has no Apple UI frameworks.

Before adding code, ask: "Could a unit test check this without a screen?" If yes, it goes into KitchenCore.

## 2. Domain modelling

- Value types by default. `struct` and `enum`, all `Sendable`, `Equatable`, `Hashable` where useful, `Codable` for anything loaded from JSON.
- Make invalid states unrepresentable. A device setting is not three optionals:
  ```swift
  public enum Rotation: Sendable, Hashable, Codable { case forward(speed: Int), reverse(speed: Int) }
  public enum Heat: Sendable, Hashable, Codable { case celsius(Int), steam }
  public struct DeviceSetting: Sendable, Hashable, Codable {
      public var heat: Heat?
      public var rotation: Rotation?
      public var duration: Duration?
  }
  ```
- Quantities that scale carry their unit and whether they scale at all ("Salz nach Gefühl" does not):
  ```swift
  public enum Amount: Sendable, Hashable, Codable { case measured(Double, Unit), toTaste }
  ```
- Scaling and formatting are separate steps. `scaled(to:)` returns a new `Amount`; formatting for German locale (comma, sensible rounding, "½" for halves if wanted) lives in one formatter with its own tests.
- Use `Duration` for times, never raw `Int` seconds in public API.
- Identifiers are typed: `struct RecipeID: Hashable, Codable, Sendable { let rawValue: String }`.

## 3. State and flow: a reducer for the cooking session

The guided cook is a state machine. Model it as one, in KitchenCore:

```swift
public struct CookingSession: Sendable, Equatable {
    public let recipe: Recipe
    public private(set) var stepIndex: Int
    public private(set) var servings: Int
    public private(set) var timer: TimerState
}
public enum TimerState: Sendable, Equatable {
    case none, ready(Duration), running(endsAt: ContinuousClock.Instant), paused(remaining: Duration), finished
}
public enum CookingAction: Sendable { case next, previous, setServings(Int), startTimer, pauseTimer, resetTimer, tick(ContinuousClock.Instant) }
extension CookingSession { public mutating func send(_ action: CookingAction) }
```

Why:
- Every transition is a pure function and gets a test, including edge cases (pause at 0, next while running, servings below 1).
- The timer stores an **end instant**, not a countdown. A counter that decrements every second drifts and dies when the app is suspended. Remaining time is always `endsAt - now`.
- Time comes in from outside (`tick(now)` or an injected `Clock`), so tests never sleep.

The App wraps the session in one `@MainActor @Observable final class CookingScreenModel` that owns a `CookingSession`, forwards user intents to `send`, and drives ticks from a `Task` with `ContinuousClock`. The view reads the model; it never mutates the session directly.

## 4. Swift 6 concurrency

- Swift 6 language mode everywhere, strict concurrency complete. Do not lower it, do not add `@preconcurrency` or `nonisolated(unsafe)` to silence the compiler. Fix the design instead.
- Domain types are `Sendable` values; they cross isolation freely.
- UI-facing models are `@MainActor`. Persistence and I/O sit behind `actor` types or `async` protocol methods.
- Long-lived work (timer ticks, loading) is a structured `Task` owned by the screen model and cancelled in `deinit` or on `.task` cancellation. Prefer SwiftUI's `.task { }` modifier, which cancels automatically.
- No `DispatchQueue`, no completion handlers, no Combine in new code.
- `@unchecked Sendable` needs a comment explaining the invariant, and a reviewer should question it.

## 5. SwiftUI on iOS 27 (App layer)

- **Deployment target is iOS 27, nothing older.** No `#available` / `@available` checks for iOS 26 or earlier, no fallback code paths, no `UIDesignRequiresCompatibility`. Where iOS 26 and 27 offer different APIs for the same thing, use the iOS 27 one. If a skill or reference describes a fallback, ignore that part.
- `@Observable` models, not `ObservableObject`. Inject with `.environment(model)` for app-wide services, pass directly for screen models.
- Navigation with `NavigationStack` and a typed path (`[Route]`, `Route: Hashable`). Deep links map to `Route`.
- One screen = one view file + one model. Subviews take plain values and closures, so previews need no model.
- Every view has a `#Preview` using fixture data from KitchenCore (`Recipe.fixtures`).
- Kitchen use: large tap targets (at least 44 pt, prefer bigger), Dynamic Type up to accessibility sizes, high contrast for values like temperature and time, `.monospacedDigit()` for the clock. Hands may be wet: no swipe-only actions, no tiny buttons.
- Keep the screen awake while a session is active (`UIApplication.shared.isIdleTimerDisabled`), and turn it off on exit.
- Timer end: local notification + haptic + sound, scheduled at `endsAt` so it fires when the app is in the background. Consider a Live Activity for the running timer.
- Liquid Glass: use the `liquid-glass` and `liquid-glass-motion` skills. Glass is for chrome (toolbars, the timer control, floating buttons), not for content cards or the step text.

## 6. Motion: modern and high fidelity

Motion is part of the product, not decoration. The bar is "feels like a first-party Apple app on iOS 27", not "animates".

- **Presets are the floor, not the target.** `.smooth`, `.snappy`, `.bouncy` are fine for a first pass. Every motion the cook sees often (step change, timer start/finish, servings stepper, glass controls morphing) gets tuned on device: `Spring(duration:bounce:)` chosen per interaction and checked on a real iPhone at 120 Hz.
- **Named motion tokens.** All values live in one `enum Motion` in the App target (`Motion.stepAdvance`, `Motion.timerPulse`, `Motion.glassMorph` ...). No magic numbers in views.
- **Interruptible and continuous.** Every animation can be interrupted mid-flight without a jump. Gesture-driven motion (swipe between steps, drag on the timer) follows the finger and hands its release velocity to the spring.
- **Choreography over single tweens.** Multi-part moments (a step completes, the next one arrives, the timer appears) use `KeyframeAnimator` / `PhaseAnimator`, matched geometry, `navigationTransition(.zoom)` and Liquid Glass morphing (`glassEffectID`, `GlassEffectContainer`) so elements travel instead of popping.
- **Sensory feedback in sync.** `sensoryFeedback` fires on the frame the motion lands (step done, timer finished), not when the tap starts.
- **Reduce Motion is a design, not an off switch.** With `accessibilityReduceMotion` on, replace travel and bounce with cross-fades and opacity, keep the timing and the feedback.
- **Performance is part of fidelity.** No hitches while scrolling glass chrome; profile with Instruments as the `liquid-glass-motion` skill describes before calling a motion done.
- Pick values with the `apple-motion-feel` skill; build them with `liquid-glass-motion`.

## 7. Persistence and data

- Bundled recipes: JSON in `Sources/KitchenCore/Resources`, decoded by KitchenCore, validated by a test that loads every file.
- User data (favourites, last servings, own recipes): App layer behind the `RecipeStore` protocol. SwiftData is fine there; never let `@Model` types leak into KitchenCore. Map at the boundary.
- Schema changes to bundled JSON get a version field and a decoding test for the old shape.

## 8. Dependencies

- Default answer to a new package is no. Foundation, SwiftUI and Swift Testing cover this app.
- A dependency must build on Linux if KitchenCore uses it, be actively maintained, and be pinned by version in `Package.resolved`.

## 9. Testing

- Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest, for new tests.
- Every public KitchenCore function and every `CookingAction` has tests. Parameterised tests for scaling tables.
- No sleeping in tests. Inject a clock or pass instants.
- `swift test` must pass in the cloud container before a PR. UI code is verified on the Mac in Xcode; say so in the PR when a change could not be compiled here.

## 10. Naming and style

- Code, identifiers and comments in English. User-facing strings in German via String Catalogs (`Localizable.xcstrings`) in the App target; KitchenCore returns values, not sentences.
- `swift format` with the repo config before committing.
- Access control is deliberate: KitchenCore API is `public`, everything else `internal` or `private`.

## Review checklist

1. Does KitchenCore still import only Foundation?
2. Is new logic in KitchenCore with tests, and is the view thin?
3. Are new types `Sendable` values, and is UI state `@MainActor`?
4. Does the timer depend on instants, not on counting ticks?
5. Can a wet hand use the new UI? Dynamic Type, contrast, target size?
6. Is the code iOS 27 only, with no fallback paths for older systems?
7. Does every visible motion use a named token, survive interruption, and have a Reduce Motion variant?
8. Does `swift build` and `swift test` pass on Linux?
