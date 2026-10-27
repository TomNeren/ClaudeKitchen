# ClaudeKitchen: Status

Stand: 27.10.2026, `main` auf `35c3cfe` (Merge von PR #46). Zusammengetragen aus allen ClaudeKitchen-Sessions (Cloud und lokal), der Git-Historie und GitHub. Entscheidungen stehen in `ENTSCHEIDUNGEN.md`, der Plan steht in `PLAN.md`.

## Kurzfassung

- **Code:** Die Meilensteine M0 bis M12 sind gemergt, einschließlich „Import vor dem Speichern bearbeiten“ (#40). Dazu kommen M14 (Startseite mit Bildband, Kochprotokoll, „Mit Claude verbessern“) und der nach dem REWE-Test geschärfte Einkaufsauftrag (#46). M13 (parallele Timer) ist nur geplant.
- **Qualität:** 244 Tests in 32 Suiten sind grün (unter Linux am 27.10. nachgeprüft). Auf `main` sind die CI-Jobs `kitchencore-linux` und `app-ios` grün.
- **Inhalt:** 30 Rezepte aus neun Küchenräumen plus ein eigenes Rezept. Alle 30 haben ein Foto (BFL).
- **Gerät:** Nichts ist bisher am iPhone geprüft. Die Geräte-Prüfliste in `PLAN.md` §10 ist komplett offen.
- **TestFlight:** Der Workflow läuft bei jedem Push auf `main`, überspringt den Upload aber, weil die Secrets fehlen.

## Meilensteine

| # | Inhalt | Stand | PR |
|---|---|---|---|
| M0 | Repo-Gerüst, KitchenCore, CI, Umgebung | erledigt | #1, #2 |
| M1 | Modelle, Skalierung, `DeviceProfile.validate`, Kochsitzung | erledigt | #3, #9 |
| M2 | Bibliothek und Rezeptansicht mit Glas | erledigt | #4 |
| M3 | Kochmodus mit Gerätekonsole und Timer | erledigt | #5 |
| M4 | AlarmKit, Live Activity, Siri | erledigt | #6, #7 |
| M5 | Barrierefreiheit, iPad, Motion, Icon | erledigt | #8 |
| M6 | Import über die Claude API | erledigt | #10 |
| M7 | Sprachmodus Schicht 2 und 3 | erledigt | #11 |
| M8 | Evidenz-Datenbank, Katalog, Nährwerte | erledigt | #12, #14, #16 |
| M9 | Gesund umschreiben mit vier Zielen | erledigt | #18, #19, #20 |
| M10 | 27 traditionelle Rezepte aus 9 Küchen | erledigt | #21 bis #30 |
| M11 | Einkauf, Vorrat, Erinnerungen, Einkaufs-Agent | erledigt | #32 bis #38 |
| M12 | Sprachprotokoll, Ersatzlisten, Editor | erledigt | #13 |
| M13 | Parallele Timer | geplant, nicht gebaut | #15 (Plan) |
| | Kochpflicht Bohnen, Vegetarisch, „Erkannt als“ | erledigt | #31, #36, #37 |
| | TestFlight-Workflow, Bundle-ID, nur iPhone und iPad | erledigt | #39, #41 |
| | iOS-27-Deprecations im Sprachcode | erledigt | #42 |
| | Rezept-Wächter und Prompt für 90 Rezepte | erledigt | #43 |
| M14 | Startseite mit Bildband, Kochprotokoll, Verbessern mit Claude | erledigt | #44 |
| | Einkaufsauftrag nach REWE-Test geschärft | erledigt | #46 |
| | Import vor dem Speichern bearbeiten | erledigt | #40 |

`PLAN.md` §8 und §9 sind auf diesem Stand (Entscheidungen 42 bis 49, offene Fragen 1 bis 3 als entschieden markiert, neue offene Frage 7).

## Offene Pull Requests

Keine außer diesem Doku-PR. PR #40 wurde am 27.10. mit dem aktuellen `main` zusammengeführt, CI grün, gemergt als `ec59ef6`.

## Wartet auf dich

### TestFlight einrichten (TFL)

1. `git pull` ausführen, dann `xcodegen generate --spec App/project.yml`.
2. In Xcode mit der Apple-ID des Schulkontos anmelden.
3. `App/Config/Local.xcconfig` mit der Team-ID des Schulkontos anlegen.
4. Die App mit der Bundle-ID `com.tomren.claudekitchen` in App Store Connect anlegen.
5. Einmal ein Archiv von Hand hochladen.
6. Vier Secrets im GitHub-Environment `testflight` eintragen: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, `APPLE_TEAM_ID`.

### Am Gerät prüfen

Die Geräte-Prüfliste steht in `PLAN.md` §10. Am wichtigsten sind:

- Ein Rezept komplett per Sprache durchkochen.
- AlarmKit bei gesperrtem iPhone.
- Live-Activity-Knöpfe.
- Gerätewerte der Rezepte am echten Omni Cook.
- Den API-Schlüssel eintragen und einen Import testen.

Neu dazugekommen ist:

- Startseite: Bildband und Zoom von einer fahrenden Kachel. Zwei Taps im Simulator öffneten nichts.
- Bewertungsblatt des Kochprotokolls.
- „Mit Claude verbessern“ mit echtem Schlüssel. Das lief noch nie gegen die API.

### Sonstiges

- **Rückmeldung:** Das Sprachprotokoll nach ein paar Kochvorgängen teilen, damit die Regeln aus Entscheidung 20 nachgeschärft werden können.
- **Einkaufs-Agent:** Der REWE-Test ist gelaufen (Regeln in #46 geschärft), ein zweiter Shop steht aus.
- **Antworten von außen:** TOKIT (Herstelleranfrage) und REWE (E-Mail) stehen aus.
- **Entscheidungen:** Siehe `ENTSCHEIDUNGEN.md` §13. Am dringendsten ist M13 (parallele Timer).

## Technische Nacharbeit (bekannt, nicht gebaut)

**Aus PR #44 (LP2, SBF):**

- Die Detailansicht zeigt noch die Initiale statt des Fotos.
- Ein Rezept, das aus einem anderen Rezept geöffnet wird, zoomt von seiner Listenkarte.
- Gesunde Varianten werden unter der ID des Originals protokolliert.
- Wird das Kochen per Sprache beendet, entsteht kein Protokolleintrag.
- Eine falsche ID in der Antwort von Claude verwirft die ganze Antwort und kostet einen bezahlten zweiten Versuch.
- Eine zweite Verbesserung ergibt die ID `…-v1-v1`.
- Die Sterne nutzen `Color.yellow` statt eines Palettentokens.

**Aus GRD:**

- Der Vegetarisch-Schalter greift nicht in Rezepten, die schon geöffnet sind.
- Die Bohnenmenge nach dem Einweichen.
- Lieblingsprodukte für den Einkaufs-Agenten merken.

**Aus IOS:**

- Ein Test für die Fehlerzuordnung des Sprachmodells.
- Eigene Texte für `.contextSizeExceeded` und `.rateLimited`.
- Die Beschreibung von PR #42 sagt noch „nicht kompiliert“.

**Aus RWA:** Die 90 neuen Rezepte sind nicht erzeugt. Geplant sind Stapel zu 10 je Küche, jeder Stapel ein eigener PR mit dem Prompt `Prompts/rezepte-erweitern.md`.

## Aufräumen

- **Mac-Runner:** Runner `kitchen-mini` vom öffentlichen Repo entfernen. Ob das geschehen ist, ist nicht bestätigt (CLD).
- **Cloud-Umgebung:** Die Netzwerk-Freigaben für 9 deutsche und 7 französische Supermärkte sind noch aktiv (SUP).
- **Setup-Skript:** Einmal in einem frischen Container prüfen. Bisher lief es nur in der laufenden Session (CLD).
- **Xcode-27-Skills:** Den Export von Apples Skills über eine Mac-Session nachholen (CLD).
- **Reste auf dem Mac:**
  - `.claude/zwischenstand-startseite.md` im lokalen Repo ist veraltet und nicht committet. Löschen oder durch diese Datei ersetzen.
  - Worktree `bold-jemison-cad08f` und Branch `claude/rezept-qualitaet`, falls noch vorhanden.
  - Aus der Vorläufer-Session TOK: entpackte TOKIT-APK und `kochfuehrung.html` im Scratchpad.
  - Das Android-Testhandy ist eventuell noch per Wireless Debugging gekoppelt.
- **BFL-Schlüssel:** Er steht in `~/.zshrc` ohne `export`. Das Bildskript bekommt ihn nur, wenn er beim Aufruf übergeben wird.

## Architektur auf einen Blick

Das graphify-Ergebnis liegt in `graphify-out/`:

- `graph.html` ist interaktiv und öffnet sich im Browser.
- `GRAPH_REPORT.md` ist der Bericht.
- `graph.json` sind die Rohdaten.

Kennzahlen: 2507 Knoten, 5386 Kanten, 111 Gruppen. Die Knoten mit den meisten Verbindungen sind:

- `PLAN.md`
- `CookingSession`
- `KitchenCore`
- `Food`
- `ShoppingModel`
- `RecipeEditorModel`
- `DeviceSetting`
- `ShoppingList`

Es gibt keine Import-Zyklen.

Auffällig ist die Gruppe „App-Modelle und Dienste“ mit einem Zusammenhalt von 0,06. Die App-Modelle teilen wenig, ihr gemeinsamer Nenner sind KitchenCore und Foundation. Das passt zur Architektur, die Logik in KitchenCore und dünne Screen-Modelle vorsieht.

Der Graph zeigt den Stand von `fc2beb2` (vor PR #40, der vier Dateien in Editor und Import ändert). `graphify update .` aktualisiert den Code ohne Sprachmodell, vergibt die Gruppennamen dabei aber neu nach Nummer, sodass Namen und Inhalte auseinanderlaufen können. Sauberer ist ein voller Neuaufbau mit `/graphify`.

## Vorschläge

1. **Ein Kochabend am Gerät** bringt mehr als jeder weitere Meilenstein. Fast alles Offene hängt an der Geräte-Prüfliste.
2. **TestFlight-Secrets eintragen:** Erst dann landet jeder Stand automatisch auf dem iPhone, und ein Kochabend wird billig.
3. **`STATUS.md` bei jedem Merge mitpflegen** (Stufe G5 im Gauntlet), damit `PLAN.md`, `STATUS.md` und `ENTSCHEIDUNGEN.md` nicht wieder auseinanderlaufen.
4. **Rezeptstapel:** Mit den 90 Rezepten erst beginnen, wenn mindestens drei Bestandsrezepte am Gerät geprüft sind. Sonst vervielfachen sich Fehler in Zeiten und Stufen.
