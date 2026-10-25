# ClaudeKitchen

Swift-App (iOS/iPadOS 26+), die Rezepte für den TOKIT Omni Cook Schritt für Schritt aufbereitet.
Gesamtplan und Entscheidungen: `PLAN.md`.

## Regeln
- Sprache der App und der Doku: Deutsch. Keine Gedankenstriche (em dash) in Texten.
- Kernlogik gehört in das Paket `OmniKit` ohne SwiftUI-Abhängigkeit, damit sie unter Linux testbar bleibt.
- Gerätewerte (Temperatur, Stufen, Füllmenge, Regeln) nur über `DeviceProfile`, nie fest im UI-Code.
- Jedes Rezept-JSON muss `DeviceProfile.validate` bestehen; der Test läuft über alle Bundle-Rezepte.
- Kein eingechecktes `.xcodeproj`: Projekt wird mit XcodeGen aus `project.yml` erzeugt.

## Liquid Glass
- Vor Glas-Code den Skill `liquid-glass` laden (Verfügbarkeiten), für Animation `liquid-glass-motion`.
- Glas nur auf Bedienebene (Leisten, Gerätekonsole, Buttons), nie auf Schritttext oder Zutatenliste.
- Benachbarte Glasflächen in einen `GlassEffectContainer`. Kein `.if`-Modifier, stattdessen `.identity`.
- Keine `opacity < 1` auf Glas oder Vorfahren. Unter Glas immer Bild oder MeshGradient, keine Einfarbfläche.

## Bauen und Prüfen
- In der Cloud-Umgebung gibt es kein Xcode: `OmniKit` mit `swift test` prüfen, die App über GitHub Actions (macOS).
- Glasdarstellung nur auf echtem Gerät beurteilen, nicht anhand von Simulator-Screenshots.
