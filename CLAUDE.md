# ClaudeKitchen

Swift 6 iOS/iPadOS cooking app: guided step-by-step cooking for a multicooker, with device settings per step, timers and portion scaling.

**Targets iOS 27 only** (Swift 6.4.1, `swift-tools-version: 6.4`). No fallbacks for older systems. Motion is modern and high fidelity: tuned, interruptible, tokenised (see `app-architecture`, section 6).

## Layout

- `Package.swift`, `Sources/KitchenCore`, `Tests/KitchenCoreTests`: platform-neutral logic. Builds and tests on Linux.
- `App/` (to come): Xcode project with the SwiftUI app. Builds only on a Mac with Xcode.

Read the `app-architecture` skill before adding features or types. KitchenCore imports only Foundation.

## Commands

```bash
swift build --build-tests
swift test
swift format lint --recursive Sources Tests
```

## CI

`.github/workflows/ci.yml` runs build, test and strict lint on a self-hosted runner (the owner's Mac, labels `self-hosted, macOS`, Xcode 27). Jobs wait while the Mac is offline.

## Cloud sessions

Cloud sessions run on Linux: there is no Xcode, iOS SDK, SwiftUI or simulator. Write and test logic in KitchenCore. App code written in the cloud is not compiled there; say so in the PR.

## Skills in this repo

- `app-architecture`: our own rules for structure, concurrency, state, testing.
- `liquid-glass`, `liquid-glass-motion`, `apple-motion-feel`: Liquid Glass material, motion and spring values (MIT, Yordi de Kleijn).
- `swiftui-expert-skill`: SwiftUI for iOS with SDK 27 API reference (`references/latest-apis.md`), state, layout, lists, performance, Instruments traces (MIT, Antoine van der Lee).
