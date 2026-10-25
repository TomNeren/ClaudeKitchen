# ClaudeKitchen: Aufbauplan

Stand: 2026-10-25 · Status: Entwurf zur Freigabe

## 1. Ziel

Eine native Swift-App, die Rezepte für den **TOKIT Omni Cook** aufbereitet und Schritt für Schritt
durch die Zubereitung führt. Jeder Schritt sagt genau, was am Gerät einzustellen ist (Modus,
Temperatur, Stufe, Laufrichtung, Zeit), mit mitlaufendem Timer und skalierbaren Mengen.

Vorbild ist das Artefakt **„Omni Cook Kochführung“** (claude.ai/artifact/QBwd6P2ymkX53jfTrn5fay).
Übernommen werden Informationsarchitektur, Datenstruktur und Farbcharakter, umgesetzt im
**Liquid-Glass-Design** von iOS 26.

## 2. Was das Artefakt vorgibt (Ausgangslage)

| Bereich | Im Artefakt | In der App |
|---|---|---|
| Startansicht | 3 Rezeptkarten mit Glyphe, Tag, Zeit, Portionen | Rezeptliste mit Suche, Filter nach Küche/Tag, Favoriten |
| Rezeptansicht | Fortschrittspunkte, ein Schritt pro Bildschirm | Kochmodus als Vollbild-Pager, Wischen und Tasten |
| Geräte-Einstellungen | Kacheln Temperatur / Stufe bzw. Linkslauf / Zeit, Dampf als Sonderwert | Typisiertes Modell `DeviceSetting`, schwebende Glas-Konsole |
| Timer | Start/Pause/Reset, Piepton | Timer läuft im Hintergrund weiter, Mitteilung + Live Activity |
| Zutaten | nur auf Schritt 1, Portionen 1 bis 8 | eigene Zutatenansicht + Zutaten pro Schritt eingeblendet |
| Hinweise | Fußzeile „So liest du die Werte“ | Regeln im Gerätemodell, Warnungen direkt am Schritt |
| Theme | Hell/Dunkel per Knopf | Systemdarstellung, keine eigene Umschaltung |

## 3. Funktionsumfang

### MVP (Version 1)
1. **Rezeptbibliothek**: Liste/Raster, Suche, Filter, Favoriten. Startbestand: die 3 Rezepte des Artefakts.
2. **Rezeptdetail**: Bild/Hero, Eckdaten, Portionen-Stepper, skalierte Zutatenliste, Schrittübersicht.
3. **Kochmodus**: ein Schritt pro Seite, große Schrift, Gerätekonsole mit Einstellungen und Timer,
   Bildschirm bleibt an (`isIdleTimerDisabled`), Fortschrittsanzeige.
4. **Timer**: läuft bei gesperrtem Gerät weiter, lokale Mitteilung bei Ablauf, Live Activity
   auf Sperrbildschirm und Dynamic Island.
5. **Mengen skalieren**: mit Plausibilitätsprüfung gegen die Füllmenge des Topfs.

### Version 2 (Vorschläge)
- **Rezept-Import**: Text oder URL einfügen, Claude API wandelt in das strukturierte Omni-Cook-Format um
  (Modus, Temperatur, Stufe, Zeit je Schritt). Ergebnis wird gegen die Geräteregeln validiert,
  bevor es gespeichert wird. Das ist der eigentliche Mehrwert von „aufbereiten“.
- **Eigene Rezepte** anlegen und bearbeiten (SwiftData).
- **Einkaufsliste** aus mehreren Rezepten, Export an Erinnerungen.
- **Freihändige Bedienung**: „Weiter“ per Sprache (App Intents / Siri) oder per Annäherung, weil
  man beim Kochen schmutzige Hände hat.
- **Wochenplan**.

### Bewusst nicht im Plan
- Direkte Gerätesteuerung über Bluetooth/WLAN: siehe Abschnitt 6, nur falls eine offene Schnittstelle existiert.

## 4. Plattform und Technik

| Entscheidung | Empfehlung | Begründung | Alternative |
|---|---|---|---|
| Plattform | **iOS 26 / iPadOS 26**, iPhone + iPad | In der Küche liegt meist das iPad, unterwegs (Einkauf) das iPhone | macOS 26 als Phase 3 über denselben Code |
| Mindestversion | **iOS 26.0** | Liquid Glass ohne Fallback-Zweige, halbiert den Designaufwand | iOS 18 mit Material-Fallback, nur sinnvoll bei Veröffentlichung im Store für breites Publikum |
| UI | SwiftUI, `@Observable`, Swift 6 strikte Nebenläufigkeit | Stand der Technik, passt zu Liquid Glass | |
| Navigation | `NavigationSplitView` (iPad) / `NavigationStack` (iPhone), `Tab`-Modell | Standardkomponenten bekommen Glas automatisch | |
| Daten v1 | Rezepte als versioniertes **JSON im Bundle** (`Codable`) | Einfach, versionierbar, von Claude leicht erzeugbar und prüfbar | SwiftData sofort, lohnt erst mit eigenen Rezepten |
| Daten v2 | **SwiftData** für Favoriten, eigene Rezepte; optional CloudKit-Sync | Gerätesync ohne Server | |
| Projektstruktur | **XcodeGen** (`project.yml`) statt eingechecktem `.xcodeproj` | Keine Merge-Konflikte in `project.pbxproj`, Projekt aus Text erzeugbar | Tuist, oder reines SwiftPM-App-Paket |
| Kernlogik | eigenes Swift Package **`OmniKit`** (Modelle, Skalierung, Geräteregeln, Timerlogik), ohne UI-Abhängigkeit | Läuft und testet auch unter Linux, also hier in der Cloud-Umgebung | |
| Tests | Swift Testing für `OmniKit`, UI-Tests für Kochmodus | | |
| CI | **GitHub Actions auf macOS-Runner** (Xcode 26): `xcodegen`, `xcodebuild build test` | Hier gibt es kein Xcode; ohne CI kann ich App-Code nicht kompilieren | Nur lokal auf deinem Mac bauen |

**Wichtig zur Arbeitsweise:** In dieser Cloud-Umgebung läuft Linux ohne Xcode. Ich kann hier
`OmniKit` mit einer Swift-Toolchain für Linux bauen und testen, die SwiftUI-App selbst aber nur über
den macOS-Runner in GitHub Actions kompilieren. Optische Prüfung von Liquid Glass geht nur auf
echtem Gerät oder im Simulator auf deinem Mac (Simulator-Darstellung von Glas ist nicht verlässlich).

## 5. Datenmodell (OmniKit)

```swift
struct Recipe: Codable, Identifiable {
    let id: String
    var name: String
    var tag: String                 // "Mediterran · Ikaria"
    var cuisine: Cuisine
    var baseServings: Int
    var totalMinutes: Int
    var heroImage: String?          // Asset-Name
    var ingredients: [Ingredient]
    var steps: [Step]
    var schemaVersion: Int
}

struct Ingredient: Codable, Identifiable {
    let id: String
    var name: String
    var amount: Amount              // .grams(30), .pieces(1), .teaspoons(2), .toTaste
    var scales: Bool                // Lorbeerblatt skaliert nicht linear
}

struct Step: Codable, Identifiable {
    let id: String
    var phase: String               // "Anschwitzen"
    var text: String
    var note: String?
    var ingredientIDs: [String]     // Zutaten, die in diesem Schritt dazukommen
    var setting: DeviceSetting?
    var accessory: Accessory?       // .steamer, .basket, .whisk
}

struct DeviceSetting: Codable {
    var mode: Mode                  // .manual, .steam, .knead, .sousVide, .ferment, .weigh ...
    var temperature: Temperature?   // .celsius(120) | .steam
    var speed: Speed?               // .level(5) | .reverse(1) | .turbo
    var duration: Duration?
}

struct DeviceProfile {              // Grenzwerte und Regeln je Modellvariante
    var temperatureRange: ClosedRange<Int>
    var temperatureStep: Int
    var speedLevels: ClosedRange<Int>
    var maxFillLiters: Double
    var rules: [Rule]               // z. B. "über 60 °C keine hohe Stufe"
}
```

`DeviceProfile.validate(recipe)` prüft jedes Rezept gegen die Gerätegrenzen. Diese Prüfung läuft
als Test über alle Bundle-Rezepte und später für jedes importierte Rezept.

Umrechnungen aus dem Artefakt, die korrigiert werden:
- Skalierung rundet derzeit auf eine Nachkommastelle („1,5 Stk Zwiebel“). Neu: Stückzahlen auf
  halbe/ganze runden, Gewürze in TL/EL-Brüchen, Gramm auf 5 g.
- Garzeiten skalieren nicht linear mit der Menge, Mengen schon. Zeiten bleiben fix, bei mehr als
  1,5-facher Menge erscheint ein Hinweis.
- Gesamtvolumen wird gegen die Füllmarke geprüft (Artefakt nennt 2,2 l), Portionen-Stepper begrenzt sich daran.

## 6. Gerät: TOKIT Omni Cook

Recherchestand 2026-10-25. Es gibt nur Testberichte und Händlerseiten, Handbuch und Herstellerseite
fehlen noch. Alle Werte gehören deshalb in ein austauschbares `DeviceProfile`, nicht fest in den Code.

| Parameter | Omni Cook (Original) | Sicherheit |
|---|---|---|
| Topf | 2,2 l Edelstahl | belegt |
| Temperatur | 35 bis 180 °C, Schrittweite unbekannt | mittel (eine Quelle nennt 30 °C) |
| Drehzahl | ca. 40 bis 12.000 U/min, 20 Stufen vorwärts, 10 rückwärts | unsicher, nur eine Quelle |
| Modi | manuell + ca. 15 Programme: Wiegen, Kneten, Hacken, Mahlen, Entsaften, Dämpfen, Schmoren, Sous-vide, Joghurt | belegt |
| Waage | integriert, ±1 g | unsicher |
| Zubehör | Dampfkorb, Schneebesen, Spatel, Messlöffel; Dampfaufsatz-Set separat | belegt |
| Sicherheitsregeln (Stufe bei Hitze), maximale Laufzeit, Füllmarke | nicht gefunden | offen |
| Offizielle Plattform | Rezept-Cloud „cookNjoy“, geführte Rezepte steuern das Gerät über WLAN | belegt |
| Offene Schnittstelle (API/Bluetooth) | nicht gefunden | vermutlich keine |

Eine Variante **Omni Cook C2** (3 l, 7-Zoll-Display, WLAN) taucht bei Händlern auf. Das Profil wird
deshalb pro Modell gepflegt, und in den Einstellungen wählst du dein Modell.

**Folgen für den Plan:**
- Das Artefakt nutzt „Stufe 5“ und „Linkslauf 1“. Bei 20 Vorwärtsstufen kann das am Gerät etwas ganz
  anderes bedeuten als beim Thermomix (10 Stufen). **Alle Rezeptwerte müssen einmal am echten Gerät
  geprüft werden**, bevor sie als verlässlich gelten. Dafür bekommt jedes Rezept ein Feld `verified`.
- Die App ist eine **Begleit-App zum manuellen Modus**. Sie steuert das Gerät nicht, weil keine offene
  Schnittstelle bekannt ist. Das ist auch ihr Vorteil: Sie funktioniert offline und mit eigenen Rezepten.
- **Dein Beitrag:** Modell und Handbuch (PDF oder Fotos der Bedienseiten). Damit fülle ich die offenen
  Zeilen und die Sicherheitsregeln.

Quellen: techadvisor.com (Omni Cook Review), the-ambient.com, china-gadgets.de, howtocookthat.net.

## 7. Liquid-Glass-Designkonzept

Grundregel: **Glas nur auf der Bedienebene, die über dem Inhalt schwebt. Inhalt bleibt Inhalt.**

### Was das für das Artefakt bedeutet
Das Artefakt arbeitet mit flachen Cremeflächen (`#f4efe6`) und Karten mit Rand und Schatten. Glas über
einer einfarbigen Fläche wirkt wie ein getöntes Rechteck, der Effekt verpufft. Deshalb ändert sich der
Inhaltslayer:
- **Rezeptfotos** als Hero und Kartenhintergrund, randlos unter die Leisten laufend.
- Ohne Foto: ein warmer **MeshGradient** aus der Artefakt-Palette (Terrakotta, Kräutergrün, Petrol)
  als Hintergrund, damit das Glas etwas zu brechen hat.

### Wo Glas hinkommt
| Element | Umsetzung |
|---|---|
| Tab-Leiste, Navigationsleisten, Suche | Standardkomponenten, Glas automatisch; `tabBarMinimizeBehavior(.onScrollDown)` |
| **Gerätekonsole** im Kochmodus | Schwebende Leiste unten: Kacheln Temperatur / Stufe / Zeit + Timer in einem `GlassEffectContainer`, `.regular`, Temperatur-Kachel mit Terrakotta-Tönung, Stufe mit Kräutergrün |
| Schritt-Navigation | „Zurück“ `.buttonStyle(.glass)`, „Weiter“ `.buttonStyle(.glassProminent)` mit `.tint(terracotta)` |
| Portionen-Stepper | Glas-Kapsel über dem Hero-Bild |
| Timer läuft | Konsole morpht vom Kachelzustand in eine große Uhr (`glassEffectID`, Details mit dem Skill liquid-glass-motion) |

### Wo bewusst kein Glas hinkommt
Schritttext, Hinweise, Zutatenliste, Rezeptkarten-Inhalt. Das ist Inhalt und muss ruhig und lesbar
bleiben, auch mit nassen Fingern aus 60 cm Abstand.

### Farben und Schrift
- Palette aus dem Artefakt als Asset-Farben mit Hell/Dunkel-Varianten: `accent` Terrakotta
  (#b5552a / #e58a5c), `herb` (#5c7148 / #a3bd84), `cool` (#2f6f7a / #7db8c2).
- Display-Schrift: Systemschrift mit `.fontDesign(.serif)` (New York) statt Fraunces einzubetten.
  Gleicher Charakter, Dynamic Type gratis. Zahlen mit `.monospacedDigit()`.
- Keine dünnen Schriftschnitte auf Glas, SF Symbols statt Rastergrafiken in Bedienelementen.

### Barrierefreiheit
Reduce Transparency und Increase Contrast übernimmt das System. Wir prüfen: Dynamic Type bis XXL im
Kochmodus, Trefferflächen mindestens 44 pt, VoiceOver liest Geräteeinstellung als Satz
(„Temperatur 120 Grad, Linkslauf Stufe 1, 3 Minuten“).

## 8. Meilensteine

| # | Inhalt | Ergebnis / Abnahme |
|---|---|---|
| M0 | Repo-Gerüst: `CLAUDE.md`, `project.yml`, `OmniKit`-Paket, GitHub Actions (macOS), SessionStart-Hook | CI baut leere App grün |
| M1 | `OmniKit`: Modelle, JSON-Schema, 3 Rezepte migriert, Skalierung, `DeviceProfile.validate`, Timer-Logik | Alle Tests grün, auch unter Linux |
| M2 | Bibliothek + Rezeptdetail mit Glas-Chrome, Palette, Hero/MeshGradient | Screenshots vom Gerät |
| M3 | Kochmodus mit Gerätekonsole, Timer, Bildschirm-wach | Ein Rezept komplett durchkochbar |
| M4 | Hintergrund-Timer, Mitteilungen, Live Activity | Timer überlebt Sperren und App-Wechsel |
| M5 | Barrierefreiheit, iPad-Layout, Feinschliff Motion | Test-Checkliste abgehakt |
| M6 | (v2) Rezept-Import über Claude API, eigene Rezepte | Importiertes Rezept besteht Validierung |

## 9. Offene Entscheidungen (mit Empfehlung)

1. **Nur für dich oder App Store?** Empfehlung: zunächst privat (TestFlight/eigenes Gerät). Bei Store-Ziel
   Markenrecht beachten: „TOKIT“ und „Omni Cook“ nicht im App-Namen, nur als „für TOKIT Omni Cook“.
2. **Mindestversion iOS 26.** Empfehlung: ja.
3. **Rezeptbilder:** eigene Fotos, KI-generiert (Skill gemini-image-gen) oder zunächst nur MeshGradient.
   Empfehlung: MeshGradient für M2, Bilder später austauschbar.
4. **Rezeptquelle langfristig:** handkuratiert als JSON oder Import per Claude API. Empfehlung: beides,
   Import ab M6.
5. **Apple Developer Account / Signing** für Gerätetests und Live Activities nötig.
