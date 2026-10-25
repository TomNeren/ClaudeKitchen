# ClaudeKitchen: Aufbauplan

Stand: 2026-10-25 · Status: freigegeben, abgeglichen mit PR #1 (KitchenCore, Projekt-Skills)

## 1. Ziel

Eine native Swift-App, die Rezepte für den **TOKIT Omni Cook** aufbereitet und Schritt für Schritt
durch die Zubereitung führt. Jeder Schritt sagt genau, was am Gerät einzustellen ist (Modus,
Temperatur, Stufe, Laufrichtung, Zeit), mit mitlaufendem Timer und skalierbaren Mengen.

Vorbild ist das Artefakt **„Omni Cook Kochführung“** (claude.ai/artifact/QBwd6P2ymkX53jfTrn5fay).
Übernommen werden Informationsarchitektur, Datenstruktur und Farbcharakter, umgesetzt im
**Liquid-Glass-Design** von iOS 27.

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
- **Sprachmodus** mit Gespräch statt nur Vorlesen, siehe Abschnitt 3a.
- **Wochenplan**.
- **Dampf-Menüs**: Hauptgericht im Dampfaufsatz, Beilage im Topf gleichzeitig (z. B. Lachs oben, Reis
  unten). Die App plant die Reihenfolge so, dass beides zur selben Zeit fertig ist.

### 3a. Sprachmodus: mit dem Handy übers Kochen reden

Ziel: Beim Kochen mit nassen Händen fragen „Was ist der nächste Schritt?“, „Wie lange noch?“ oder
„Mir fehlt der Feta, was kann ich nehmen?“ und eine gesprochene Antwort bekommen. Vorlesen allein reicht nicht.

**Was die Live Activity dabei leisten kann und was nicht:** Sie zeigt Schritt und Timer auf dem
Sperrbildschirm und in der Dynamic Island und bekommt Knöpfe („Weiter“, „Timer starten“) über App Intents.
Ein Gespräch kann sie nicht führen. Das Gespräch läuft im Kochmodus der App, die ohnehin den Bildschirm
wach hält. Bei gesperrtem Gerät übernimmt Siri über dieselben App Intents.

**Aufbau in drei Schichten:**

| Schicht | Technik | Was sie kann |
|---|---|---|
| 1. Feste Befehle | App Intents + Siri, Knöpfe in der Live Activity | „Weiter“, „Zurück“, „Timer starten“, „Wie lange noch?“, auch bei gesperrtem Gerät |
| 2. Gespräch im Kochmodus | `SpeechAnalyzer` (Spracherkennung auf dem Gerät) → Absichtserkennung → Antwort per `AVSpeechSynthesizer` | Freies Sprechen ohne Tippen; einfache Fragen werden ohne KI beantwortet |
| 3. Offene Fragen | Foundation Models (Sprachmodell von Apple auf dem Gerät) mit Werkzeugen für aktuellen Schritt, Zutaten und Ersatzliste; optional Claude API für schwierige Fälle | „Geht das auch ohne Kokosmilch?“, „Kann ich statt Spinat Mangold nehmen?“ |

**Ersatzzutaten:** Jede Zutat im Rezept-JSON kann eine gepflegte Ersatzliste tragen (Name, Mengenverhältnis,
Hinweis). Seit M1 ist das im Datenmodell, inklusive Mengenberechnung für die gewählte Portionszahl
(`Ingredient.substitutions`). Die gepflegte Liste ist die verlässliche Antwort. Das Sprachmodell darf
darüber hinaus Vorschläge machen, kennzeichnet sie aber als ungeprüft. Ändert ein Ersatz die Garzeit
(z. B. Kabeljau statt Lachs), steht das im Hinweis.

**Wo die Logik sitzt:** Absichtserkennung für feste Befehle und Ersatzsuche liegen in `KitchenCore` und sind
unter Linux testbar. Spracherkennung, Sprachausgabe, Foundation Models und Siri liegen in der App.

**Einschränkungen, die vorher zu prüfen sind:**
- Foundation Models braucht ein Gerät mit Apple Intelligence. Dein iPhone 18 erfüllt das; Apple Intelligence
  muss eingeschaltet sein. Ohne das bleiben Schicht 1 und 2.
- Deutsch für `SpeechAnalyzer` und Foundation Models gilt als unterstützt, das prüfe ich vor dem Bau.
- Ein eigenes Weckwort („Hey Omni“) erlaubt iOS nicht. **Entschieden: dauerhaftes Zuhören.** Im Kochmodus
  hört die App zu, solange er offen ist, mit sichtbarer Mikrofonanzeige und einem Knopf zum Stummschalten.
- Dauerhaftes Zuhören kostet Akku. Für einen Kochvorgang von 30 bis 60 Minuten ist das vertretbar.

### Bewusst nicht im Plan
- Direkte Gerätesteuerung über WLAN: in einer früheren Session untersucht, derzeit nicht machbar (Abschnitt 6.2).

## 4. Plattform und Technik

| Entscheidung | Empfehlung | Begründung | Alternative |
|---|---|---|---|
| Plattform | **iOS 27 / iPadOS 27**, iPhone + iPad, nur für den Eigengebrauch | In der Küche liegt meist das iPad, unterwegs (Einkauf) das iPhone | macOS 27 als Phase 3 über denselben Code |
| Mindestversion | **iOS 27**, keine Fallbacks (Vorgabe aus `app-architecture`) | Liquid Glass ohne Ausweichzweige, neueste APIs | |
| UI | SwiftUI, `@Observable`, Swift 6 strikte Nebenläufigkeit | Stand der Technik, passt zu Liquid Glass | |
| Navigation | `NavigationStack` mit typisiertem Pfad (`[Route]`), auf dem iPad `NavigationSplitView`, `Tab`-Modell | Standardkomponenten bekommen Glas automatisch | |
| Daten v1 | Rezepte als versioniertes **JSON in `Sources/KitchenCore/Resources`** (`Codable`) | Einfach, versionierbar, von Claude leicht erzeugbar und prüfbar | SwiftData sofort, lohnt erst mit eigenen Rezepten |
| Daten v2 | **SwiftData** für Favoriten, eigene Rezepte; optional CloudKit-Sync | Gerätesync ohne Server | |
| Projektstruktur | **XcodeGen** (`App/project.yml`) statt eingechecktem `.xcodeproj` | Keine Merge-Konflikte in `project.pbxproj`, Projekt aus Text erzeugbar | Tuist, oder reines SwiftPM-App-Paket |
| Kernlogik | Swift Package **`KitchenCore`** (aus PR #1: Modelle, Skalierung, Geräteregeln, Kochsitzung als Zustandsautomat, Timer), importiert nur Foundation | Läuft und testet auch unter Linux, also hier in der Cloud-Umgebung | |
| Tests | Swift Testing für `KitchenCore`, UI-Tests für Kochmodus | | |
| CI | GitHub Actions, gehostete Runner (Repo ist öffentlich, Minuten kostenlos): Linux-Job für `KitchenCore` (Build, Test, Lint) und **macOS-Job** auf dem Image `xcode-27` (`xcodegen`, `xcodebuild` für den Simulator) | Hier gibt es kein Xcode; ohne macOS-Job kann ich App-Code nicht kompilieren | Nur lokal auf deinem Mac bauen |

**Wichtig zur Arbeitsweise:** In dieser Cloud-Umgebung läuft Linux ohne Xcode. Ich kann hier
`KitchenCore` mit Swift 6.4.1 für Linux bauen und testen, die SwiftUI-App selbst aber nur über
den macOS-Runner in GitHub Actions kompilieren. Optische Prüfung von Liquid Glass geht nur auf
echtem Gerät oder im Simulator auf deinem Mac (Simulator-Darstellung von Glas ist nicht verlässlich).

## 5. Datenmodell (KitchenCore)

Skizze nach den Regeln des Skills `app-architecture`: Werttypen, ungültige Zustände nicht darstellbar,
`Duration` statt Sekunden, typisierte IDs. `Amount` und `MeasureUnit` gibt es schon aus PR #1.

```swift
public struct Recipe: Sendable, Hashable, Codable, Identifiable {
    public let id: RecipeID
    public var name: String
    public var tag: String                  // "Mediterran · Ikaria"
    public var baseServings: Int
    public var totalTime: Duration
    public var heroImage: String?           // asset name
    public var ingredients: [Ingredient]
    public var steps: [Step]
    public var verified: Bool               // cooked once on the real device
    public var schemaVersion: Int
}

public struct Ingredient: Sendable, Hashable, Codable, Identifiable {
    public let id: IngredientID
    public var name: String
    public var amount: Amount               // .measured(30, .gram) | .toTaste
    public var scales: Bool                 // a bay leaf does not scale linearly
}

public struct Step: Sendable, Hashable, Codable, Identifiable {
    public let id: StepID
    public var phase: String                // "Anschwitzen"
    public var text: String
    public var note: String?
    public var ingredientIDs: [IngredientID]
    public var setting: DeviceSetting?
    public var accessory: Accessory?        // .steamer, .basket, .whisk
}

public enum Heat: Sendable, Hashable, Codable { case celsius(Int), steam }
public enum Rotation: Sendable, Hashable, Codable { case forward(speed: Int), reverse(speed: Int) }
public struct DeviceSetting: Sendable, Hashable, Codable {
    public var program: Program             // .manual, .steam, .knead, .sousVide, .yogurt ...
    public var heat: Heat?
    public var rotation: Rotation?
    public var duration: Duration?
}

public struct DeviceProfile: Sendable {     // limits and rules per model
    public var temperature: ClosedRange<Int>        // 35...180
    public var forwardSpeeds: ClosedRange<Int>      // 1...10
    public var reverseSpeeds: ClosedRange<Int>
    public var maxDuration: Duration                // 99 min
    public var maxFillLiters: Double                // 2.2
    public var maxSteamerLoadGrams: Int             // 2000 per layer
    public var ownedAccessories: Set<Accessory>     // steamer is owned
    public var rules: [Rule]                        // each rule has severity .error or .warning
}
```

Die Kochsitzung (`CookingSession` mit `send(_ action:)`) und der Timer mit Endzeitpunkt statt
Countdown folgen direkt dem Skill `app-architecture`, Abschnitt 3.

`DeviceProfile.validate(recipe)` prüft jedes Rezept gegen die Gerätegrenzen. Diese Prüfung läuft
als Test über alle Bundle-Rezepte und später für jedes importierte Rezept.

Umrechnungen aus dem Artefakt, die korrigiert werden:
- Skalierung rundet derzeit auf eine Nachkommastelle („1,5 Stk Zwiebel“). Neu: Stückzahlen auf
  halbe/ganze runden, Gewürze in TL/EL-Brüchen, Gramm auf 5 g.
- Garzeiten skalieren nicht linear mit der Menge, Mengen schon. Zeiten bleiben fix, bei mehr als
  1,5-facher Menge erscheint ein Hinweis.
- Gesamtvolumen wird gegen die Füllmarke geprüft (Artefakt nennt 2,2 l), Portionen-Stepper begrenzt sich daran.

## 6. Gerät: TOKIT Omni Cook

Stand 2026-10-25. Zwei Quellen: die Handbuch-Auswertung aus der früheren Session „Tokio Omni
Fernsteuerung und Rezepte“ (11. bis 23.10.) und eine Webrecherche (nur Testberichte und Händler).
Wo beide sich widersprechen, gilt das Handbuch. Alle Werte gehören in ein austauschbares
`DeviceProfile`, nicht fest in den Code.

### 6.1 Bedienwerte

| Parameter | Wert | Quelle / Sicherheit |
|---|---|---|
| Topf | max. 2,2 l Füllmarke, Edelstahl | Handbuch, belegt |
| Temperatur (manuell) | bis 180 °C; Untergrenze laut Tests 35 °C, Schrittweite unbekannt | Handbuch (Obergrenze), Tests (Untergrenze) |
| Zeit (manuell) | bis 99 Min | Handbuch |
| Stufen | **1 bis 10 vorwärts, dazu Linkslauf** (sanftes Rühren mit der Messerrückseite) | Handbuch. Ein Testbericht nennt 20 vorwärts / 10 rückwärts, das ist damit überholt |
| Sicherheitsregel „über 60 °C keine hohe Stufe“ | **entfällt** (Entscheidung 2026-10-25): stand in der früheren Handbuch-Auswertung, ist aber nicht bestätigt. Die App prüft und warnt dazu nicht | verworfen |
| Dampfgaren | nur mit separatem Aufsatz, max. 2 kg in einer Lage. **Aufsatz ist vorhanden** und wird eingeplant | Handbuch, Bestand bestätigt |
| Programme | manuell + ca. 15 Programme: Wiegen, Kneten, Hacken, Mahlen, Entsaften, Dämpfen, Schmoren, Sous-vide, Joghurt | Tests, belegt |
| Waage | integriert, ±1 g | Test, unsicher |
| Zubehör | Dampfkorb, Schneebesen, Spatel, Messlöffel; Dampfaufsatz-Set separat | Tests, belegt |

Offen bleiben: Untergrenze und Schrittweite der Temperatur, Turbo-Funktion. Eine Variante **Omni Cook C2** (3 l,
7-Zoll-Display) taucht bei Händlern auf. Das Profil wird deshalb pro Modell gepflegt.

Die Rezepte im Artefakt (Stufe 5, Linkslauf 1, 120 °C, Dampf) passen zu diesen Handbuchwerten.
Sie gelten trotzdem erst als verlässlich, wenn sie einmal am Gerät gekocht wurden: Jedes Rezept
bekommt dafür ein Feld `verified`.

**Dampfaufsatz:** Er ist vorhanden. Dampfrezepte gehören deshalb schon in den Startbestand (der
Ingwer-Lachs aus dem Artefakt nutzt ihn). Schritte mit Aufsatz zeigen ein eigenes Zubehör-Symbol, und
`DeviceProfile.validate` prüft die 2-kg-Grenze pro Lage sowie die Wassermenge im Topf. Rezepte, die
Zubehör brauchen, das nicht im Bestand ist, werden markiert statt ausgeblendet.

### 6.2 Direkter Zugriff über WLAN: Ergebnis der früheren Session

**Fazit: Direktsteuerung ist derzeit eine Sackgasse.** Die App bleibt eine Begleit-App zum manuellen
Modus.

Was beobachtet wurde:
- Die offizielle App heißt „TOKIT“ (Android-Paket `com.chunmi.tokit.overseas`, Version 1.5.2), Hersteller
  Chunmi Technology (Shanghai). Sie ist in React Native gebaut und spricht Cloud-Server unter
  **joyami.com** an. Die Steuerung läuft also über die Hersteller-Cloud, nicht lokal.
- Für TOKIT/Omni Cook gibt es keine Einträge in MIoT-Spezifikationen, in der Home-Assistant-Integration
  `xiaomi_miot` oder in Reverse-Engineering-Projekten auf GitHub.
- Die Android-App wurde per ADB vom Handy kopiert und nur statisch angesehen (Strings, Hosts).

Was nicht ging oder nicht versucht wurde:
- Den Datenverkehr der App mitzuschneiden hätte bedeutet, ihre Zertifikatsprüfung auszuhebeln. Das hat
  die Umgebung blockiert, und es wurde nicht durchgeführt. Das Format für Temperatur, Stufe und Zeit
  in geführten Rezepten ist deshalb unbekannt.
- Das Gerät selbst wurde nie im Netz gescannt. IP, offene Ports und lokales Protokoll sind unbekannt.

Offener Faden: Eine Anfrage an **service@tokitglobal.com** nach Entwicklerzugang oder Rezept-Import wurde
als Entwurf geschrieben. Ob sie verschickt und beantwortet wurde, steht nicht in der Session.

### 6.3 Folgen für den Plan

1. **Keine Gerätesteuerung in v1 und v2.** Weder Reverse Engineering des Cloud-Protokolls noch das
   Aushebeln der Zertifikatsprüfung gehören in den Plan: Das ist rechtlich heikel, würde bei jedem
   App-Update brechen und hängt an einer fremden Cloud.
2. **Bewusst offengehaltener Anschluss:** `DeviceSetting` ist so geschnitten, dass ein späterer
   `DeviceController` (falls TOKIT eine Schnittstelle oder einen Rezept-Import anbietet) die Werte
   direkt übernehmen könnte. Bis dahin gibt es nur die Anzeige-Implementierung.
3. **Antwort des Herstellers ist der Hebel.** Kommt ein offizieller Rezept-Import, wird der zum
   Exportziel der App (eigene Rezepte → TOKIT-App) statt einer Direktsteuerung.
4. **Ein harmloser Prüfschritt bleibt möglich:** Gerät im Heimnetz suchen (IP über den Router, Port-Scan
   nur des eigenen Geräts). Das zeigt, ob überhaupt ein lokaler Dienst läuft. Nur sinnvoll, wenn die
   Herstelleranfrage ins Leere läuft.

Quellen: Handbuch-Auswertung und Netzwerkversuche in der Session „Tokio Omni Fernsteuerung und Rezepte“;
techadvisor.com (Omni Cook Review), the-ambient.com, china-gadgets.de, howtocookthat.net.

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
| M0 | Repo-Gerüst. Erledigt durch PR #1: `KitchenCore`, Projekt-Skills, Linux-CI, Umgebung „ClaudeKitchen“. Neu: `App/project.yml` (XcodeGen), leere App, macOS-Job in der CI | CI baut KitchenCore und die leere App grün |
| M1 | `KitchenCore`: Modelle, JSON-Schema, 3 Rezepte migriert, Skalierung, Formatierung, `DeviceProfile.validate`, Kochsitzung mit Timer, Ersatzzutaten | Erledigt: 33 Tests grün unter Linux |
| M2 | Bibliothek + Rezeptdetail mit Glas-Chrome, Palette, Hero/MeshGradient | Screenshots vom Gerät |
| M3 | Kochmodus mit Gerätekonsole, Timer, Bildschirm-wach | Ein Rezept komplett durchkochbar |
| M4 | Hintergrund-Timer, Mitteilungen, Live Activity mit Knöpfen, App Intents für Siri (Sprachmodus Schicht 1) | Timer überlebt Sperren und App-Wechsel, „Hey Siri, nächster Schritt“ funktioniert |
| M5 | Barrierefreiheit, iPad-Layout, Feinschliff Motion | Test-Checkliste abgehakt |
| M6 | (v2) Rezept-Import über Claude API, eigene Rezepte | Importiertes Rezept besteht Validierung |
| M7 | (v2) Sprachmodus Schicht 2 und 3: Gespräch im Kochmodus, Ersatzfragen | Ein Rezept komplett per Sprache durchkochbar |

## 9. Entscheidungen

Getroffen (2026-10-25):
1. **Nur für den Eigengebrauch**, kein App Store. Markenrecht und Store-Prüfung entfallen.
2. **iOS 27 als Mindestversion**, keine Fallbacks (Vorgabe aus PR #1).
3. **Dampfaufsatz vorhanden**, Dampfrezepte gehören in den Startbestand.
4. **Herstelleranfrage an TOKIT ist verschickt**, Antwort steht aus.
5. **Repo bleibt öffentlich**, CI läuft auf gehosteten GitHub-Runnern (kostenlos für öffentliche Repos).
   Folge: keine Geheimnisse ins Repo, nie ein selbst gehosteter Runner für Pull Requests.
6. **Keine 60-°C-Regel**: nicht belegt, keine Prüfung und keine Warnung.
7. **Gerät iPhone 18, Sprachmodus mit dauerhaftem Zuhören** im Kochmodus.

Offen (mit Empfehlung):
1. **Rezeptbilder:** eigene Fotos, KI-generiert (Skill gemini-image-gen) oder zunächst nur MeshGradient.
   Empfehlung: MeshGradient für M2, Bilder später austauschbar.
2. **Rezeptquelle langfristig:** handkuratiert als JSON oder Import per Claude API. Empfehlung: beides,
   Import ab M6.
3. **Apple Developer Account / Signing** für Gerätetests und Live Activities. Für den Eigengebrauch reicht
   ein kostenloses Konto (Apps laufen 7 Tage), mit bezahltem Konto entfällt das Neusignieren.
