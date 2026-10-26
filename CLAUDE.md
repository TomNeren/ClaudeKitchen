# ClaudeKitchen

Swift 6 iOS/iPadOS cooking app: guided step-by-step cooking for a multicooker, with device settings per step, timers and portion scaling.

**Targets iOS 27 only** (Swift 6.4.1, `swift-tools-version: 6.4`). No fallbacks for older systems. Motion is modern and high fidelity: tuned, interruptible, tokenised (see `app-architecture`, section 6).

## Layout

- `Package.swift`, `Sources/KitchenCore`, `Tests/KitchenCoreTests`: platform-neutral logic. Builds and tests on Linux.
- `App/`: SwiftUI app. `App/project.yml` is the XcodeGen spec; run `xcodegen generate --spec App/project.yml` on a Mac to get `App/ClaudeKitchen.xcodeproj` (not checked in). Builds only with Xcode 27. For device builds, copy `App/Config/Local.xcconfig.example` to `App/Config/Local.xcconfig` (git-ignored) and set your `DEVELOPMENT_TEAM`; it survives every `xcodegen generate`. Never commit a team ID or certificate.

Read the `app-architecture` skill before adding features or types. KitchenCore imports only Foundation.

## Commands

```bash
swift build --build-tests
swift test
swift format lint --recursive Sources Tests
```

## CI

`.github/workflows/ci.yml` runs build, test and strict lint on a GitHub-hosted `ubuntu-24.04` runner with Swift 6.4.1 (installed via swiftly, cached), read-only permissions. A second job, `app-ios`, runs on the GitHub-hosted `xcode-27` image (macOS 27, Apple Silicon; `macos-26` only has Xcode 26): it selects Xcode 27, generates the project with XcodeGen and builds the app for the iOS Simulator without signing. The repo is public: never use a self-hosted runner for pull request jobs, since fork PRs could run code on it.

## Cloud sessions

Cloud sessions run on Linux: there is no Xcode, iOS SDK, SwiftUI or simulator. Write and test logic in KitchenCore. App code written in the cloud is not compiled there; say so in the PR.

## Skills in this repo

- `app-architecture`: our own rules for structure, concurrency, state, testing.
- `liquid-glass`, `liquid-glass-motion`, `apple-motion-feel`: Liquid Glass material, motion and spring values (MIT, Yordi de Kleijn).
- `swiftui-expert-skill`: SwiftUI for iOS with SDK 27 API reference (`references/latest-apis.md`), state, layout, lists, performance, Instruments traces (MIT, Antoine van der Lee).

## Projektregeln (TOKIT Omni Cook)

Gesamtplan, Gerätedaten und Entscheidungen: `PLAN.md`.

- Zielgerät ist der TOKIT Omni Cook (Original, 2,2 l, Dampfaufsatz vorhanden). Die App steuert das Gerät nicht, sie begleitet den manuellen Modus (`PLAN.md`, Abschnitt 6.2).
- Gerätewerte (Temperatur, Stufen, Laufzeit, Füllmenge, Zubehör, Regeln) nur über `DeviceProfile` in KitchenCore, nie fest im UI-Code.
- Jedes gebündelte Rezept muss `DeviceProfile.validate` bestehen; ein Test lädt alle JSON-Dateien.
- Keine Regel „über 60 °C keine hohe Stufe“: ist nicht belegt und wurde verworfen.
- Kein eingechecktes `.xcodeproj`: Das App-Projekt entsteht mit XcodeGen aus `App/project.yml`.
- Doku und Texte für Menschen auf Deutsch, ohne Gedankenstriche (em dash). Code und Kommentare auf Englisch (siehe `app-architecture`).
- Glas nur auf der Bedienebene (Leisten, Gerätekonsole, Buttons), nie auf Schritttext oder Zutatenliste. Unter Glas immer Bild oder MeshGradient, keine Einfarbfläche.
- Kein Geheimnis ins Repo (öffentlich): API-Schlüssel gehören in die Keychain der App.
