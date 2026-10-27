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
| 3. Offene Fragen | Foundation Models (Sprachmodell von Apple auf dem Gerät), Rezept, Portionen, aktueller Schritt und Ersatzliste als Kontext (Entscheidung 21) | „Omni, geht das auch ohne Kokosmilch?“, „Kann ich statt Spinat Mangold nehmen?“ |

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

### 3b. Gesund umschreiben: Evidenz-Datenbank und Umwandlung

Ziel: Ein traditionelles Rezept wird zu einer gesünderen Variante umgeschrieben. **Die Gewürze und das
Würzprinzip bleiben original, die Grundzutaten ändern sich** (z. B. Weißreis zu Vollkornreis oder halb
Linsen, Sahne zu Joghurt, verarbeitetes Fleisch zu Hülsenfrüchten oder Fisch). Original und Variante
stehen nebeneinander, die App zeigt, was sich geändert hat und warum.

**Evidenz-Datenbank (KitchenCore, JSON im Repo):**
- **Ebene Lebensmittelgruppe, nicht Einzelprodukt.** Gute Evidenz gibt es für Gruppen (Vollkorn,
  Hülsenfrüchte, Nüsse, Gemüse, Obst, Fisch, rotes und verarbeitetes Fleisch, Milchprodukte,
  zuckergesüßte Getränke, raffiniertes Getreide). Für einzelne Produkte wäre jede Zahl Scheingenauigkeit.
- Pro Gruppe: Richtung (günstig, neutral, begrenzen), Evidenzgrad (nur eingetragen, wenn die Quelle selbst
  GRADE oder NutriGrade nennt, sonst „nicht bewertet“), Effekt mit Dosis (z. B. relatives Risiko
  Gesamtsterblichkeit je Portion pro Tag), Zielmenge laut DGE 2024, Quellenliste mit DOI.
- Basisquellen: Dosis-Wirkungs-Metaanalyse Schwingshackl et al. 2017 (AJCN, DOI 10.3945/ajcn.117.153148),
  Umbrella Review 2025 (Adv Nutr, DOI 10.1016/j.advnut.2025.100393), DGE-Empfehlungen 2024, IARC zu
  rotem und verarbeitetem Fleisch, EAT-Lancet 2025 als Ergänzung. Jede Zahl wird vor dem Einchecken an
  der Originalarbeit geprüft; Werte aus Suchzusammenfassungen gehen nicht ungeprüft ins Repo.
- **Stand M8b:** Geprüft sind die relativen Risiken je Tagesportion für Vollkorn, Gemüse, Obst, Nüsse, Fisch,
  rotes und verarbeitetes Fleisch (Abstract Schwingshackl 2017, PMID 28446499) sowie die DGE-Zielmengen für
  Obst und Gemüse (mindestens 5 Portionen am Tag), Fleisch und Wurst (höchstens 300 g in der Woche) und Fisch
  (1 bis 2 Portionen zu rund 120 g in der Woche). Jede Zahl trägt den Wortlaut ihrer Quelle, das Skript
  `Scripts/check_evidence_quotes.py` prüft das. **Offen:** die Portionsgrößen der Studie in Gramm (stehen nur
  im Volltext, der frei nicht abrufbar ist) und die Effekte für Hülsenfrüchte, Milch, Eier und zuckergesüßte
  Getränke (im Abstract nicht beziffert). Nüsse und Samen sind getrennte Gruppen, weil die Studie nur Nüsse misst.
- Die Einstufungen sind **selbst formuliert mit Zitat**, keine kopierten Datensätze. IHME-Daten (nur nicht
  kommerziell) und Open Food Facts (Share-Alike) kommen nicht ins Repo.
- **Lebensmittelkatalog:** Jedes Lebensmittel hat eine ID, Namen und Synonyme, eine Gruppe, eine Rolle
  (Würze, Aromabasis, Grundzutat, Fett, Flüssigkeit) und Umrechnungen (Gramm je Stück, je TL/EL). Jede
  Zutat in einem Rezept verweist auf ein Lebensmittel (`food`). Ein Test prüft das für alle Rezepte.
- **Nährwerte (M8c):** kcal, Kohlenhydrate, Ballaststoffe, Eiweiß, Fett, Natrium je 100 g für jedes Lebensmittel
  im Katalog, aus USDA FoodData Central (CC0, mit FDC-ID je Eintrag zum Nachprüfen). Gebraucht für die Ziele
  Abnehmen, Low Carb und Blutdruck. Der BLS 4.0 wäre für deutsche Lebensmittel genauer, seine Lizenz für die
  Weitergabe ist aber ungeklärt. **Stand M8c:** 28 von 29 Lebensmitteln haben Nährwerte aus SR Legacy (April 2018);
  Garam Masala fehlt dort und bleibt als Gewürzmischung ohne. Nährwerte pro Portion zählen „nach Geschmack“ nicht
  mit (Salz!), die App muss das beim Ziel Blutdruck anzeigen. `Scripts/check_nutrients.py` vergleicht jeden Wert
  mit dem USDA-Datensatz.

**Umwandlung (KitchenCore, deterministisch):**
- Tauschregeln als JSON: von Lebensmittel, zu Lebensmittel, Mengenverhältnis, Begründung mit Quellenverweis,
  Folgen für die Zubereitung (zusätzliche Garzeit, Hinweis am Schritt, z. B. „Vollkornreis 15 Min länger“).
- `HealthyVariant` erzeugt aus einem Rezept die Variante und eine Änderungsliste. Feste Invarianten mit Tests:
  Würzen bleiben unverändert, die Variante besteht `DeviceProfile.validate`, Garzeiten passen sich an.
- Statt einer Gesamtnote ein **Gruppenprofil pro Portion** („Hülsenfrüchte 120 g, Vollkorn 60 g,
  verarbeitetes Fleisch 0 g“) im Vergleich zur DGE-Zielmenge. Eine einzelne Gesundheitszahl wäre nicht belegt.
- Freie Umschreibungen über die Claude API (M6) müssen dieselben Invarianten bestehen.

**Ziele (Entscheidung 25):** Du wählst ein Ziel, jedes Ziel ist ein eigener Regelsatz mit eigenen Quellen.
Die Invarianten (Würzen und Aromabasis bleiben, `validate` besteht) gelten für alle.

| Ziel | Was es ändert | Evidenzbasis (vor dem Einchecken zu prüfen) |
|---|---|---|
| **Ausgewogen (Standard)** | Vollkorn statt Weißmehl, mehr Hülsenfrüchte und Gemüse, verarbeitetes Fleisch ersetzen, Pflanzenöl statt Butter, Sahne und Kokos | DGE 2024, Schwingshackl 2017 |
| **Blutdruck** | Wie Ausgewogen, dazu weniger Salz und salzige Würzsaucen (Sojasauce, Brühe) mit Ersatz durch Säure, Kräuter, Kalium-reiches Gemüse; mehr Milchprodukte (fettarm) | DASH-Studien, WHO-Salzempfehlung |
| **Abnehmen** | Energiedichte senken: mehr Gemüse und Hülsenfrüchte, weniger Fett und Zucker, Portionsgröße mit kcal je Portion | DGE, Studien zu Energiedichte |
| **Low Carb** | Getreide, Reis, Kartoffeln und Zucker ersetzen (z. B. Blumenkohlreis, mehr Gemüse, Hülsenfrüchte in Maßen) | Evidenz gemischt: als Vorliebe geführt, nicht als „gesünder“; ein Hinweis zeigt, wo es von Ausgewogen abweicht |

Weitere Ziele (z. B. Blutzucker, Darmgesundheit, viel Eiweiß) lassen sich als neue Regelsätze ergänzen.
Widersprechen sich zwei Ziele (Vollkornreis gegen Blumenkohlreis), gewinnt das gewählte, und die App zeigt
den Unterschied zu Ausgewogen.

**Stand M9a:** Regeln stehen in `Resources/Evidence/rewrite-rules.json`, jede mit Wortlaut der DGE-Seite.
Ausgewogen tauscht Weißreis gegen Vollkornreis (15 Min länger), Nudeln gegen Vollkornnudeln (2 Min länger), Mehl zur
Hälfte gegen Vollkornmehl, Butter gegen 80 % Olivenöl und Ghee zur Hälfte gegen Olivenöl. Die Variante heißt
`<rezept>-<ziel>`, behält das Original als ersten Ersatz („Original“), rechnet Mengen in TL und EL über das Gewicht um
und überspringt einen Tausch, der die 99-Minuten-Grenze sprengen würde. Die Zusatzgarzeit kommt einmal auf den längsten
beheizten Schritt ab dem Zugeben bis zum nächsten frischen Topf; eine Regel muss die Gruppe verbessern, sonst gilt
sie als Fehler. **Offen:** Kokosmilch und Sahne. Die DGE-Seite begründet „Pflanzliche Öle bevorzugen“, sagt aber nichts
wörtlich zu Kokos oder Sahne; ein Tausch dafür braucht eine eigene Quelle (z. B. DGE-Leitlinie Fett). Von den drei
mitgelieferten Rezepten ändert Ausgewogen deshalb noch keines, die Regeln greifen bei den Rezepten aus M10.

**Stand M9b:** Jedes Ziel hat ein Kriterium: Ausgewogen die Gruppenbewertung, Blutdruck Natrium, Abnehmen kcal und
Low Carb Kohlenhydrate je 100 g. Eine Regel muss ihr Kriterium verbessern und darf die Gruppe nicht verschlechtern.
Blutdruck erbt die Regeln von Ausgewogen (eigene Regeln gehen vor), weil die DASH-Kost Vollkorn einschließt; eine geerbte
Regel darf das Kriterium des erbenden Ziels nicht verschlechtern. Abnehmen und Low Carb erben nicht: Vollkornreis hat
gleich viel kcal, und Ghee halb gegen Öl spart keine. Mengen in Stk werden zu Gramm, wenn das neue Lebensmittel kein
Stückgewicht hat (3 Kartoffeln werden 450 g Blumenkohl). Regeln und Hinweise:
- Blutdruck: Sojasauce zu salzreduzierter Sojasauce, Gemüsebrühe zur Hälfte zu Wasser (Sacks 2001, DASH-Sodium);
  Hinweis, dass Salz nach Geschmack nicht mitzählt und die DGE bis zu 6 g am Tag nennt.
- Abnehmen: Kokosmilch zur Hälfte zu Wasser (Ello-Martin 2007); Hinweis auf kcal pro Portion.
- Low Carb: Kartoffel zu Blumenkohl (Seidelmann 2018); Hinweis, dass Low Carb eine Vorliebe ist und Reis und Nudeln
  nicht im selben Schritt getauscht werden, weil Blumenkohl darin zerkocht.
Alle Zitate prüft `Scripts/check_evidence_quotes.py`. Damit ändern Blutdruck (Lachs, Linsen-Eintopf) und Abnehmen
(Curry) schon mitgelieferte Rezepte.

### 3c. Rezeptbestand: authentisch und traditionell

- Neun Küchenräume (Entscheidung 32): Indien, Thailand, Südostasien (Vietnam, Indonesien, Malaysia,
  Philippinen), China, Japan und Korea, Türkei und Levante, Georgien, Europa (Mittelmeer und Osteuropa),
  Mexiko und Peru. Startbestand 27 Rezepte (je 3), erweiterbar.
- Neue Felder: `origin` (Küche, Region), `references` (Standardwerke oder Kulturerbe-Einträge, nur
  zitiert), `variantOf` (die gesunde Variante verweist auf das Original).
- **Recht:** Zutatenlisten mit Mengen sind in der Regel nicht geschützt, ausformulierte Anleitungen schon.
  Deshalb werden alle Texte selbst formuliert, keine Texte oder Fotos aus Blogs, Kochbüchern oder Datensätzen
  wie RecipeNLG. Wikibooks (CC BY-SA) nur, wenn Namensnennung und Share-Alike für diese Datei gelten.
- **Grenze:** Ob ein Rezept authentisch ist, kann Claude nicht belegen, nur plausibel machen. Jedes Rezept
  startet mit `verified: false` und einer Prüfliste (Gewürze, Technik), die du oder jemand aus der jeweiligen
  Küche abhaken kann.
- **Qualitätsprüfung:** `RecipeQualityTests` verlangt für jedes mitgelieferte Rezept `origin` mit Region,
  Referenzen und Prüfliste, `verified: false`, ein Tag „<Küche> · <Art>“ passend zur Küche, 4 bis 10 Schritte mit
  20 bis 160 Zeichen, keine Gedankenstriche und kein doppeltes Gericht. Kichererbsen-Spinat-Curry und
  Linsen-Eintopf tragen jetzt Herkunft und eine Prüfliste, die ihre Abwandlungen offen nennt. Der Ingwer-Lachs bleibt
  ein eigenes Rezept ohne Herkunft: Er steht als einziger in `ownCreations` im Test, braucht keine Referenzen und
  darf kein Küchen-Adjektiv im Tag tragen. Neue Rezepte entstehen mit `Prompts/rezepte-erweitern.md` und kommen
  nie in diese Liste.

### 3d. Einkauf und Vorrat

- **Vorrat:** Bestand pro Lebensmittel (Menge und Einheit). Gewürze nur als „da, fast leer, leer“. Für
  Grundvorräte (Reis, Linsen, Öl) ein Mindestbestand.
- **Abbuchen:** Am Ende des Kochmodus („Fertig“) werden die skalierten Mengen vom Vorrat abgezogen, mit
  Rückgängig.
- **Einkaufsliste = Bedarf minus Vorrat**, plus alles unter dem Mindestbestand. Gleiche Lebensmittel werden
  zusammengefasst und in Einkaufseinheiten gerundet, sortiert nach Marktbereich (Obst und Gemüse, Trockenware,
  Kühlung). Nach dem Einkauf bucht „Eingekauft“ die Liste in den Vorrat.
- **Übergabe:** Export in eine Liste in Apple Erinnerungen (EventKit) und als Text über das Teilen-Menü
  (z. B. für Bring!).
- **REWE-Abholung: kein offizieller Weg.** REWE, Picnic, Knuspr, Flink, EDEKA und Kaufland bieten keine
  öffentliche Schnittstelle für Warenkorb oder Liste. Es gibt nur reverse-engineerte Bibliotheken. Die kommen
  aus demselben Grund nicht in den Plan wie die Gerätesteuerung (Abschnitt 6.3): AGB, Zugangsdaten, Bruch bei
  jedem Update. Die REWE-Bestellung bleibt Handarbeit mit der sortierten Liste als Vorlage.
- Logik (Bedarf, Vorrat, Zusammenfassen, Runden) liegt in KitchenCore. Gespeichert wird wie bei eigenen
  Rezepten als JSON in Application Support (Entscheidung 18).

### 3e. Parallele Timer

**Ausgangslage:** Die Kochsitzung kennt genau einen Timer. Läuft er, bleibt er beim Schrittwechsel stehen
(Entscheidung 10), und der Timer des neuen Schritts lässt sich erst nach Ablauf oder Zurücksetzen starten.

**Was wirklich parallel läuft:** Der Omni Cook hat einen Topf, also läuft immer höchstens ein Gerätetimer.
Parallel ist nur Arbeit neben dem Gerät: Reis auf dem Herd, etwas im Ofen, Einweichen, Marinieren, Ruhen
lassen. Die drei ersten Rezepte brauchen das nicht (beim Curry kommt der Blumenkohl laut Schritt 5 erst nach
dem Umfüllen in den sauberen Topf). Seit M10 ist der Bedarf belegt (Stand M10h, 24 Rezepte):
- Wartezeiten neben dem Gerät ohne Timer: Dal Tadka (30 Min einweichen), Jeera-Reis (20 Min einweichen),
  Chicken Adobo (30 Min marinieren). Kocht man Dal und Reis zusammen, laufen beide gleichzeitig.
- Kurze Pfannenarbeit ohne nennenswerte Zeit: Mercimek Çorbası (Butter mit Pul Biber), Chicken Adobo
  (anbraten). Braucht keinen Timer.
- Einweichen über Nacht (Kuru Fasulye, Lobio) ist kein Timer, sondern eine Erinnerung am Vortag und gehört
  nicht in M13.
Dazu kommen importierte Rezepte aus M6, die oft Herd oder Ofen nutzen.

**Regeln:**
- Ein Schritt hat höchstens einen Timer: entweder den Gerätetimer (`setting.duration`) oder einen neuen
  **Nebentimer** mit Ort (Herd, Ofen, Arbeitsfläche) und Dauer. Beides zugleich lehnt `validate` ab.
- **Höchstens ein Gerätetimer** ist aktiv (laufend oder pausiert). Ein zweiter Start wird abgelehnt, die
  Oberfläche sagt warum („Das Gerät läuft noch: Köcheln, 8 Minuten“).
- **Nebentimer laufen unabhängig**, höchstens 4 gleichzeitig (Grenze im `DeviceProfile`, weil Sperrbildschirm
  und Dynamic Island nicht mehr sinnvoll zeigen).
- Entscheidung 10 bleibt: Jeder aktive Timer gehört zu seinem Schritt und läuft beim Schrittwechsel weiter.
  Neu ist nur, dass der Timer des aktuellen Schritts trotzdem startbar ist.
- Zurücksetzen und Pause wirken auf den Timer des aktuellen Schritts. Andere Timer bedient man über ihre
  eigene Zeile in der Timer-Liste.

**Datenmodell (KitchenCore), Skizze:**
```swift
public enum TimerPlace: String, Sendable, Hashable, Codable { case device, stove, oven, counter }
public struct SideTimer: Sendable, Hashable, Codable {   // new optional field Step.sideTimer
    public var place: TimerPlace                         // never .device, checked by validate
    public var duration: Duration
}
public struct ActiveTimer: Sendable, Equatable {
    public let stepID: StepID
    public let place: TimerPlace
    public var state: TimerState                         // existing enum, unchanged
}
// CookingSession: `timer` and `timerStepIndex` become `timers: [ActiveTimer]` (sorted by end instant).
// `timer` stays as the current step's timer, so CookingStatus, Siri and the view keep working during the switch.
// CookingAction.startTimer/pauseTimer/resetTimer get an optional StepID (nil = current step).
// New: CookingSession.startRefusal(for:) -> .deviceBusy(ActiveTimer) | .tooManyTimers | nil
```
- `finishedTimerCount` zählt weiter jeden abgelaufenen Timer einzeln, auch wenn ein Tick mehrere beendet.
- `TimerAlarm` bekommt die `StepID` als stabile Kennung; die Sitzung liefert `alarms: [TimerAlarm]`.
- Rezept-JSON bekommt `schemaVersion` 2 mit `sideTimer`; ein Test dekodiert die alte Form unverändert.

**App:**
- `AlarmScheduler.apply(_ alarms: [TimerAlarm])` gleicht ab statt alles zu löschen: neue Alarme planen,
  verschwundene abbrechen, laufende in Ruhe lassen. `SystemAlarmScheduler` führt dafür eine Zuordnung
  `StepID` zu `Alarm.ID`. Heute löscht er bei jeder Änderung alle Alarme der App, das muss weg.
- Kochmodus: Die Timer-Zeile in der Gerätekonsole wird eine Liste. Der Timer des aktuellen Schritts steht
  oben, andere aktive Timer darunter als kompakte Zeilen mit Ort, Schrittname und Restzeit; Tippen springt
  zum Schritt. Glas bleibt auf der Bedienebene (Projektregel).
- Schritt-Live-Activity: zusätzlich „2 Timer“ und der nächste Ablauf. Die Countdowns selbst zeigt AlarmKit,
  je Timer einer.
- Siri und Sprachmodus: „Wie lange noch“ nennt alle aktiven Timer, der früheste zuerst, höchstens drei.
  „Timer starten“ und „Timer pausieren“ meinen den aktuellen Schritt; hat er keinen, aber genau ein anderer
  Timer läuft, diesen. Bei mehreren sagt die App, welche laufen, und bittet um den Knopf.
- Editor (M12) und Import (M6): Feld „Nebentimer“ mit Ort und Dauer; das Import-Schema bekommt dasselbe Feld.

### Bewusst nicht im Plan
- Direkte Gerätesteuerung über WLAN: in einer früheren Session untersucht, derzeit nicht machbar (Abschnitt 6.2).
- Warenkorb-Übergabe an REWE oder andere Händler über inoffizielle Schnittstellen (Abschnitt 3d).
- Eine einzelne Gesundheitsnote pro Rezept (Abschnitt 3b).

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
| M2 | Bibliothek + Rezeptdetail mit Glas-Chrome, Palette, Hero/MeshGradient, Suche | Erledigt (PR #4): CI grün, 41 Tests; Optik offen laut Geräte-Prüfliste |
| M3 | Kochmodus mit Gerätekonsole, Timer, Bildschirm-wach | Erledigt (PR #5): CI grün, 47 Tests; Durchkochen offen laut Geräte-Prüfliste |
| M4 | Hintergrund-Timer, Mitteilungen, Live Activity mit Knöpfen, App Intents für Siri (Sprachmodus Schicht 1) | Erledigt: M4a Timer per AlarmKit (PR #6), M4b/M4c Live Activity mit Schritt-Knöpfen und Siri (PR #7); 53 Tests; Bedienung offen laut Geräte-Prüfliste |
| M5 | Barrierefreiheit, iPad-Layout, Feinschliff Motion, App-Icon | Erledigt (PR #8); Gefühl und Lesbarkeit offen laut Geräte-Prüfliste |
| M6 | (v2) Rezept-Import über Claude API, eigene Rezepte | Erledigt (PR #10, 68 Tests): Import aus Text oder https-Link, Prüfung, Speichern, Löschen; Editor bei Bedarf; Test am Gerät braucht API-Schlüssel |
| M7 | (v2) Sprachmodus Schicht 2 und 3: Gespräch im Kochmodus, Ersatzfragen | Erledigt (PR #11, 76 Tests): `VoiceCommand` in KitchenCore, Zuhören, Antworten und KI-Fragen in der App; Durchkochen per Sprache offen laut Geräte-Prüfliste |
| M8 | M8a erledigt (PR #12), M8b erledigt (PR #14), M8c erledigt (PR #16). Evidenz-Datenbank: Lebensmittelgruppen mit Quellen, Lebensmittelkatalog, `food`-Verweis an jeder Zutat (Abschnitt 3b) | Alle Zahlen an der Originalarbeit geprüft; Test: jede Zutat aller Rezepte ist zugeordnet, jede Einstufung hat eine Quelle |
| M9 | Erledigt: M9a (PR #18), M9b (PR #19), M9c (PR #20). Gesund umschreiben: Tauschregeln, `HealthyVariant`, Gruppenprofil, Ziele Ausgewogen, Blutdruck, Abnehmen, Low Carb; in der App Umschalter Original/Variante mit Zielwahl, Änderungsliste und Quellen | Invarianten-Tests: Würzen unverändert, Variante besteht `validate` |
| M10 | Erledigt: M10a (PR #21), M10b Indien (PR #22), M10c Thailand (PR #23), M10d Südostasien (PR #24), M10e China (PR #25), M10f Japan und Korea (PR #26), M10g Türkei und Levante (PR #27), M10h Georgien (PR #28), M10i Europa (PR #29), M10j Mexiko und Peru (PR #30). Rezept-Wächter und Prompt für neue Stapel (PR #43, Entscheidung 45). Rezeptbestand: `origin`, `references`, `variantOf`, Ziel 27 traditionelle Rezepte aus neun Küchenräumen, Stand 29 aus allen neun (Indien und Europa mit je vier, weil das Kichererbsen-Curry und der Linsen-Eintopf von Ikaria dazuzählen), Ziel erreicht (ohne das eigene Lachsrezept); Bibliothek filtert nach Küche. Offen: Ausbau auf etwa 10 Rezepte je Küche in Stapeln | Alle bestehen `validate` und sind vollständig zugeordnet; Stapel bestehen zusätzlich `RecipeQualityTests` |
| M11 | Erledigt: M11a0 Zuordnung über Namen (PR #32). M11a Logik (PR #33). M11b1 App mit Plan, Liste, Vorrat und Abbuchen (PR #34). M11b2 Export nach Erinnerungen (PR #35). „Erkannt als“ (PR #36). Vegetarisch als Standard (PR #37). Einkaufs-Agent (PR #38), nach dem REWE-Test geschärft (PR #46). Einkauf und Vorrat: Bedarf minus Vorrat, Mindestbestand, Abbuchen nach dem Kochen, Export nach Erinnerungen und Teilen (Abschnitt 3d) | Logik-Tests in KitchenCore; Export am Gerät laut Prüfliste; Einkaufs-Agent bei REWE getestet, zweiter Shop offen |
| M12 | (v2) Sprachprotokoll, Ersatzlisten für alle Rezepte, Rezept-Editor für das Handy, Import vor dem Speichern bearbeiten | Erledigt (PR #13, Import-Bearbeiten PR #40); Bedienung am Handy offen laut Geräte-Prüfliste |
| M14 | Startseite und Kochprotokoll: Bildband mit Rezeptfotos, Zoom in die Rezeptansicht, Kochprotokoll mit Bewertung, „Mit Claude verbessern“ (Entscheidungen 46 bis 48) | Erledigt (PR #44): 30 Fotos, 233 Tests; Zoom, Bewertungsblatt und Verbessern mit echtem Schlüssel offen laut Geräte-Prüfliste. Bekannt: Rezeptansicht zeigt noch die Initiale statt des Fotos |
| M13 | Parallele Timer (Abschnitt 3e): höchstens ein Gerätetimer, dazu bis zu 4 Nebentimer für Herd, Ofen und Arbeitsfläche. M13a KitchenCore, M13b App (Alarme abgleichen, Timer-Liste, Live Activity, Siri), M13c Editor und Import | Tests: zweiter Gerätetimer abgelehnt; Gerätetimer und Nebentimer laufen und enden unabhängig; ein Tick beendet mehrere und zählt jeden; Zurücksetzen trifft nur den aktuellen Schritt; Entscheidung 10 gilt weiter; altes Rezept-JSON dekodiert unverändert; `validate` lehnt Schritt mit beiden Timern ab. Am Gerät laut Prüfliste |

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
8. (Loop, umkehrbar) **Portionen 1 bis 8**, zusätzlich begrenzt durch die Füllmarke; Detail und Kochmodus nutzen denselben Bereich.
9. **App-Icon** (von dir bestätigt): dampfender Topf in Creme auf Terrakotta-Verlauf, erzeugt von `App/Tools/make_app_icon.py` (hell, dunkel, getönt). Austauschbar gegen ein eigenes.
10. (Loop, umkehrbar) **Ein laufender Timer bleibt beim Schrittwechsel erhalten** und zeigt „Timer aus Schritt N“; erst Zurücksetzen lädt den Timer des aktuellen Schritts.
11. (Loop, umkehrbar) **Mit „Bewegung reduzieren“** wechseln Schritte per Überblendung und nur über die Knöpfe, ohne Wischen.
12. (Loop, umkehrbar) **Timer im Hintergrund über AlarmKit** statt normaler Mitteilung: klingelt auch bei Stumm-Modus und Fokus, mit Countdown auf Sperrbildschirm und Dynamic Island (Widget-Extension). Ein abgelaufener Alarm klingelt weiter, bis du ihn stoppst.
13. (Loop, umkehrbar) **Zwei Live Activities**: eine für den Schritt mit Knöpfen Zurück und Weiter, die AlarmKit-Anzeige für den Countdown. So bleibt die Schritt-Anzeige auch ohne Timer stehen.
14. (Loop, umkehrbar) **Siri und die Knöpfe wirken nur, solange der Kochmodus offen ist** (auch im Hintergrund). Ist die App beendet, antwortet Siri „Gerade ist kein Kochmodus offen.“
15. (Loop, umkehrbar) **Motion**: alle Animationen sind tippgesteuert und daher ohne Nachschwingen (`bounce: 0`), 0,3 bis 0,4 s. Ausnahme: die Timer-Ziffern mit 0,25 s, weil sie innerhalb jeder Sekunde zur Ruhe kommen müssen. Wischen, Siri und Live-Activity-Knöpfe wechseln Schritte ohne eigene Animation; der Wisch-Pager behält die Systemfeder.
16. (Loop, umkehrbar) **iPad**: Kochmodus mit Schritt links und Bedienleiste rechts (40 % der Breite, höchstens 400 pt) in regulärer Breite; ein gemeinsamer Ansichtsbaum für alle Größen.
17. **Rezept-Import über die Claude API mit API-Schlüssel** (deine Entscheidung). Ein Claude-Abo ist für eigene Apps nicht zugelassen, das Agent SDK läuft nicht auf iOS. Die App ruft die Messages API per HTTPS auf (kein offizielles Swift-SDK), Modell Claude Opus 5.5 mit niedrigem Aufwand, Antwort als festes JSON-Schema, danach `DeviceProfile.validate`. Schlüssel nur in der Keychain.
18. (Loop, umkehrbar) **Eigene Rezepte als JSON-Dateien** in Application Support, im selben Format wie die mitgelieferten, statt SwiftData. Einfacher, ohne Migrationen, jederzeit exportierbar.
19. (Loop, umkehrbar) **Kein Rezept-Editor in M6.** Importierte Rezepte lassen sich ansehen, kochen und löschen; Ändern heißt vorerst neu importieren. Ein Editor kommt, wenn du ihn vermisst. Überholt durch M12 (Entscheidung 31).
20. (Loop, umkehrbar) **Was beim Dauerzuhören zählt:** Feste Befehle („weiter“, „wie lange noch“, „Timer starten“, „welche Zutaten“) nur, wenn der Satz im Wesentlichen der Befehl ist (höchstens zwei Zusatzwörter wie „bitte“), auch nach „Omni“: „Omni, was mache ich, wenn der Reis nicht fertig ist?“ geht nicht weiter, sondern ist eine Frage. Ersatzfragen ohne „Omni“ („mir fehlt Lachs“, „was kann ich statt Kokosmilch nehmen“) nur bis 8 Wörter, und die App schweigt, wenn die Zutat nicht im Rezept steht („ich habe keine Ahnung …“). Nach „Omni“ geht alles Übrige ans Sprachmodell, auch „Omni, kann ich statt Spinat Mangold nehmen?“; nur „Omni, mir fehlt …“ und „Omni, Ersatz für …“ bleiben Ersatzfragen. Ein echtes Weckwort, das das Gerät aufweckt, erlaubt iOS nicht; „Omni“ filtert nur im laufenden Zuhören.
21. (Loop, umkehrbar) **Freie Fragen mit Apples Sprachmodell auf dem Gerät**, nicht mit der Claude API: ohne Netz, ohne Kosten, schnell genug zum Vorlesen. Jede Frage bekommt eine neue Sitzung mit Rezept, Portionen, aktuellem Schritt, Ersatzliste und Gerätegrenzen als Kontext statt Werkzeugaufrufen (Rezepte sind kurz, das Kontextfenster läuft nie voll). Antworten stehen als „KI-Antwort, ungeprüft“ in der Statusanzeige. Ersatz aus der gepflegten Liste geht immer vor, das Modell kommt nur bei Zutaten ohne Liste dran.
22. (Loop, umkehrbar) **Zuhören startet mit dem Kochmodus** (Entscheidung 7) und lässt sich über das Mikrofon oben rechts abschalten; das Abschalten gilt auch für spätere Kochvorgänge. Während die App spricht, ist das Mikrofon stumm, damit sie sich nicht selbst hört. Ausgabe über den Lautsprecher, andere Audio-Wiedergabe wird leiser. Im Hintergrund hört die App nicht zu (dafür sind Siri und die Live Activity da) und setzt beim Zurückkehren fort. Nach einem Anruf, Siri oder einem Wechsel auf AirPods startet sie das Zuhören von selbst neu (höchstens dreimal ohne erkannten Satz dazwischen).
23. (Loop, umkehrbar) **Schrittbefehle per Sprache gehen denselben Weg wie Siri** (`CookingIntentTarget.perform`) und sagen dasselbe. „Weiter“ im letzten Schritt beendet den Kochmodus nicht, das bleibt beim Knopf.

24. (Loop, umkehrbar) **Reihenfolge nach M7: M8 → M9 → M10 → M11.** Alles ist weitgehend unter Linux testbar.
    Importierte Rezepte (M6) bekommen ab M8 ebenfalls `food`-Verweise, damit sie umgeschrieben und eingekauft
    werden können.
25. **„Gesund“ ist wählbar** (deine Entscheidung): Ausgewogen nach DGE 2024 und Studien als Standard, dazu
    Blutdruck, Abnehmen und Low Carb als eigene Regelsätze, erweiterbar (Abschnitt 3b). Low Carb wird als
    Vorliebe geführt, nicht als gesünder, weil die Evidenz gemischt ist.
26. (Loop, umkehrbar) **Würzen und Aromabasis sind unantastbar:** Lebensmittel mit Rolle „Würze“ (Gewürze, Kräuter,
    Würzsaucen, Säure) oder „Aromabasis“ (Zwiebel, Knoblauch, Ingwer) werden nie getauscht oder in der Menge verändert.
    Salz ist die Ausnahme, die nur einen Hinweis bekommt. Gewichte je Stück, TL und EL im Katalog sind
    Haushaltsnäherungen, keine Messwerte.
27. **Keine REWE-Anbindung über inoffizielle Schnittstellen** (Abschnitt 3d), Einkaufsliste über Erinnerungen und Teilen.
28. (Loop, umkehrbar) **Nährwerte aus USDA FoodData Central (CC0)** als Scheibe M8c, weil Abnehmen und Low Carb
    sie brauchen. Der BLS bleibt Option, falls seine Lizenz die Weitergabe erlaubt.
29. (umkehrbar) **Sprachprotokoll ist an** (von dir gewünscht) und lässt sich in den Einstellungen abschalten. Es schreibt jeden Satz mit, den der Kochmodus hört, auch die ignorierten, mit erkanntem Befehl und Antwort. Höchstens 500 Einträge, nur auf diesem Gerät, teilbar als Text (Tabulator-getrennt) und löschbar. Teile es nach ein paar Kochvorgängen, dann schärfe ich die Regeln aus Entscheidung 20 nach.
30. (umkehrbar) **Ersatzlisten für alle drei Rezepte** ergänzt, zusätzlich zu den Einträgen aus M8a. Ersatz steht immer in der Einheit der Originalzutat; wo das irreführt (Knoblauch als Pulver, Lorbeer) bleibt die Liste leer und das Sprachmodell darf mit „Omni“ helfen. Wasser und Salz haben keinen Ersatz.
31. (umkehrbar) **Rezept-Editor für das Handy:** ein Formular mit Rezept, Zutaten und Schritten, Details eine Ebene tiefer, Sortieren über einen Knopf unten. Neue Zutaten und Schritte öffnen sich sofort zum Ausfüllen. Alle Gerätewerte (Temperatur in 5er-Schritten, Stufen, Laufzeit) kommen aus `DeviceProfile`, Dampf setzt Programm und Aufsatz mit. Sichern geht erst ohne Fehler (Name, Schritttext, Gerätegrenzen), Warnungen wie die Füllmarke bleiben sichtbar. Mitgelieferte Rezepte werden als eigene Kopie bearbeitet, das Original bleibt. Neue Rezepte über „+“ in der Bibliothek. Für die Bedienung mit einer Hand: Zutaten als Zeile tippen („200 g Rote Linsen“, Eingabe, nächste) oder eine ganze Liste einfügen, die App zerlegt Menge, Einheit und Name selbst (g, kg, ml, l, TL, EL, Stk, Zehen, Brüche wie ½). Temperatur, Stufe und Laufzeit per Schnellwahl mit einem Tipp, Feineinstellung per Stepper. Schritte nach rechts wischen dupliziert, nach links löscht. Über der Zahlentastatur steht „Fertig“, Scrollen schließt die Tastatur.
32. **Küchen für M10** (deine Entscheidung): Indien, Thailand, Südostasien, China, Japan und Korea, Türkei und
    Levante, Georgien, Europa, Mexiko und Peru, je 3 Rezepte.
33. (Loop, umkehrbar) **Blutdruck darf eine Würze gegen ihre salzarme Variante tauschen**, etwa Sojasauce gegen
    salzreduzierte Sojasauce. Das lockert Entscheidung 26 nur für ausdrücklich im Katalog verknüpfte Paare
    (`lowSodiumVersionOf`); Geschmack und Menge bleiben gleich.
34. (Loop, umkehrbar) **Kochpflicht für rohe Bohnen:** Lebensmittel können im Katalog eine Mindestkochzeit mit
    Quelle tragen (`mustBoil`). Kidneybohnen und weiße Bohnen: 30 Minuten in frischem Wasser nach dem Einweichen
    (BfR-Stellungnahme 03/2024). `validate` warnt, wenn die Schritte ab der Zugabe bis zum nächsten frischen Topf
    zusammen kürzer bei mindestens 100 °C kochen; Dampf und Dampfaufsatz zählen nicht, ein frischer Topf mit den
    Bohnen zählt mit. Dosenbohnen sind eigene Lebensmittel ohne Kochpflicht. Nur eine Warnung, weil das Gerät nicht
    erkennen kann, ob der Topf in der Aufheizzeit schon sprudelt. Gilt für jedes Rezept, dessen Zutaten einem
    Lebensmittel zugeordnet sind; seit M11a0 ordnen Import und Editor neue Zutaten selbst zu (Entscheidung 35).
35. (Loop, umkehrbar) **Zutaten werden über Namen und Aliase zugeordnet** (`FoodMatcher`): Name oder Alias muss
    als ganze Wörter im Zutatennamen stehen, verglichen nach Wortstamm (Groß- und Kleinschreibung, Akzente und
    übliche Endungen zählen nicht, „roten Linsen“ findet „Rote Linsen“). Ein Name mit Zusatz nach dem Komma passt nur
    ganz, die Kurzform braucht einen Alias, damit „Paprika“ nicht zu „Paprika, rot“ wird. Der längste Treffer
    gewinnt, bei Gleichstand keiner. Import, Editor und das Laden gespeicherter Rezepte ordnen neue und umbenannte
    Zutaten zu; findet ein neuer Name nichts, bleibt das alte Lebensmittel. Rohe und Dosenbohnen haben eigene Aliase.
    An den mitgelieferten Rezepten: 353 von 355 Zutaten erkannt, keine falsch; ein Test hält Trefferquote (mindestens
    90 Prozent) und Fehlerfreiheit.
36. (Loop, umkehrbar) **Einkauf und Vorrat in KitchenCore** (M11a): Der Marktbereich steht an der Gruppe, mit
    Ausnahmen am Lebensmittel (frische Kräuter bei Obst und Gemüse, Tofu und Kimchi in der Kühlung, Erbsen und Mais
    tiefgekühlt). Würzen und Saucen außerhalb von Obst und Gemüse zählen als „da, fast leer, leer“, alles andere in
    Gramm mit optionalem Mindestbestand; ein Vorratseintrag behält die Art, mit der er angelegt wurde. Die Liste rundet auf ganze Stück, wo das Lebensmittel ein Stückgewicht hat, sonst auf 10 g (bis
    100 g), 50 g (bis 1 kg) und 100 g. Mengen „nach Geschmack“ setzen eine Zutat nur auf die Liste, wenn nichts
    mehr da ist. Würzen ohne Vorratseintrag stehen als „prüfen“ auf der
    Liste. Kochen bucht Gramm ab, Füllstände nicht; Einkaufen bucht Gramm zu und setzt Würzen auf „da“.
37. (deine Entscheidung) **Vegetarisch als Standard:** Das Ziel „Vegetarisch“ tauscht Fleisch gegen Tofu
    (Hähnchen zu Tofu, Hack zu zerbröseltem Tofu, Schweinebauch zu Räuchertofu). Fisch und tierische Würzen
    (Fischsauce, Garnelenpaste, Austernsauce, Katsuobushi) bleiben im Original; ihre vegetarische Alternative steht
    oben in der Ersatzliste (Regelart `offer`). Eier und Milch bleiben. Rezepte mit Fleisch öffnen in der
    vegetarischen Variante, in den Einstellungen abschaltbar. Quelle: DGE 2024 (pflanzliche Lebensmittel steigern,
    tierische senken; Fisch 1 bis 2 Portionen pro Woche).
38. (Loop) **REWE:** Nutzungsbedingungen von App (Stand 13.06.2023), Kundenkonto (27.08.2025) und Lieferservice
    gelesen. Kein ausdrückliches Bot-Verbot, aber: App 6.1.3 verbietet das Extrahieren von App-Inhalten (also kein
    Nachbau der App-Schnittstelle), Kundenkonto 3.4 verbietet die Nutzung durch Dritte (keine Zugangsdaten in der App
    oder auf Servern), 1.11 erlaubt Sperren bei Verdacht auf Manipulation. Der Shop hat Bot-Schutz, robots.txt sperrt
    Suchanfragen für Crawler. Weg: Die App liefert REWE-Suchbegriffe und eine Liste für einen Agenten im eigenen,
    eingeloggten Browser des Nutzers, der vor der Kasse prüft.
39. (deine Entscheidung) **Einkaufs-Agent, shopunabhängig:** Statt REWE-eigener Begriffe hat jedes Lebensmittel
    einen neutralen Suchbegriff (`Food.searchTerm`: `searchName` im Katalog, sonst der Name ohne Kommas, etwa
    „Tofu natur“ für „Tofu, fest“). „Teilen > Für Einkaufs-Agenten“ erzeugt einen Einkaufsauftrag (`AgentBrief`) für
    einen Agenten im eigenen, eingeloggten Browser, in welchem Shop auch immer: nur Warenkorb, keine Kasse, keine
    Konto-, Adress- oder Zahlungsdaten, keine Captchas lösen, sondern anhalten. Artikel mit unbekanntem Vorrat stehen
    unter „Erst fragen“. Am Ende eine Tabelle mit Produkt, Menge, Preis und Fehlendem.
40. (deine Entscheidung) **TestFlight über das Schulkonto:** Du verwaltest das Entwicklerkonto der Schule und bist
    der einzige Nutzer. Die Bundle-ID `com.tomren.claudekitchen` hängt nicht an der Schule; ein späterer Umzug auf ein
    eigenes Konto geht per App-Transfer. Der Workflow `testflight.yml` lädt jeden Stand von `main` hoch, nie Pull
    Requests; die Zugangsdaten liegen im GitHub-Environment `testflight`, das nur `main` nutzen darf. Ohne sie wird
    der Upload übersprungen. Einrichtung: `App/TESTFLIGHT.md`.
41. (deine Entscheidung) **Import vor dem Speichern bearbeiten:** In der Import-Vorschau öffnet „Bearbeiten“ Claudes Rezept im Editor. „Sichern“ dort speichert und schließt den Import, „Abbrechen“ führt zurück zur Vorschau. So lassen sich auch Fehler beheben, die das Speichern blockieren, statt neu zu importieren (kostet keinen weiteren API-Aufruf).

42. (deine Entscheidung) **Nur iPhone und iPad:** Mac (Designed for iPad), Apple Vision und Catalyst sind in
    `App/project.yml` abgeschaltet (PR #41).
43. (deine Entscheidung) **Bundle-ID `com.tomren.claudekitchen`**, das Widget `com.tomren.claudekitchen.widgets`
    (PR #41). Einheitlich mit den anderen Apps; verworfen `de.tomneren.*`. Die ID lässt sich nach dem Anlegen in
    App Store Connect nicht mehr ändern.
44. (deine Entscheidung) **Signing über eine lokale Datei:** `DEVELOPMENT_TEAM` steht in der ignorierten
    `App/Config/Local.xcconfig` (Vorlage `Local.xcconfig.example`), das Gerät wird per WLAN aus Xcode bespielt
    (PR #17). Verworfen: eine Umgebungsvariable, weil XcodeGen `${DEVELOPMENT_TEAM}` sonst wörtlich ins Projekt
    schreiben kann.
45. (deine Entscheidung) **Rezeptqualität und Ausbau:** Etwa 10 Rezepte je Küche, erzeugt in Stapeln zu 10 mit
    `Prompts/rezepte-erweitern.md`, je Stapel ein PR. `RecipeQualityTests` prüfen jedes Rezept: Herkunft mit Region,
    mindestens eine Quelle und zwei Prüfpunkte, `verified` ist `false`, keine Gedankenstriche, 4 bis 10 Schritte,
    Schritttext 20 bis 160 Zeichen, Tag „Küche · Art“, keine Dubletten (PR #43). Bei Bestandsrezepten werden Daten
    ergänzt, nicht die Tests gelockert. Der Ingwer-Lachs bleibt eine eigene Kreation ohne Herkunft und steht als
    einziges Rezept in der Ausnahmeliste `ownCreations`; erzeugte Rezepte kommen dort nie hinein. Verworfen: ein
    JSON-Feld `ownCreation` (Schemaänderung für ein Rezept) und „Herkunft darf fehlen“ (erzeugte Rezepte kämen
    unbemerkt durch).
46. (deine Entscheidung) **Startseite mit Rezeptfotos:** Bildband aus zwei gegenläufigen Reihen oben, darunter die
    Liste mit Fotos (Variante A); verworfen ein reines Fotoraster (Dauer und Portionen schlechter zu überblicken).
    Fotos aus BFL FLUX.2 pro über `Scripts/generate_recipe_images.py`, alle im Stil der ersten drei Probebilder;
    verworfen Gemini (weniger fotorealistisch bei Essen) und Canva (uneinheitlich, schlecht skriptbar). Der
    Schlüssel bleibt außerhalb des Repos. Beantwortet die frühere offene Frage 1 (Rezeptbilder).
47. (deine Entscheidung) **Kochprotokoll:** `CookLog` in `cooklog.json` merkt sich jeden Kochvorgang mit optionaler
    Bewertung 1 bis 5 und Notiz. Die Kapsel auf der Karte ist dunkel und ohne Glas, weil sie Inhalt ist und keine
    Bedienung. Verworfen: nur das Datum speichern, weil dann die Grundlage zum Verbessern fehlt.
48. (deine Entscheidung) **„Mit Claude verbessern“:** Claude schlägt aus Rezept und Protokoll eine Variante vor. Sie
    muss `DeviceProfile.validate`, die Zutatenprüfung und den Lebensmittelkatalog bestehen; du speicherst sie als
    eigenes Rezept oder verwirfst sie. Gleicher Weg wie der Import (Entscheidung 17), Schlüssel in der Keychain.
49. (nach dem REWE-Test) **Einkaufsauftrag geschärft** (PR #46): „Erst fragen“-Artikel werden am Anfang geklärt
    (keine Auswahl heißt keiner), eine größere Packung wird genommen, wenn sie billiger ist, Buttons werden vor dem
    Klick geprüft, Ersatz kommt mit Preis (TK bei Fisch und Fleisch ist in Ordnung), am Ende gleicht der Agent den
    Warenkorb mit der Auswahl ab. Ergänzt Entscheidung 39.
50. (deine Entscheidung) **TestFlight bei jedem Push auf `main`:** Jeder gemergte Stand geht nach TestFlight, kein
    Upload nur bei Tags. Beantwortet die offene Frage 7. Ob ein übersprungener Upload sichtbar gemacht wird, ist
    noch nicht entschieden.

Die Herkunft dieser und weiterer Entscheidungen aus den einzelnen Sessions steht in `ENTSCHEIDUNGEN.md`.

Offen (mit Empfehlung; die Nummern bleiben, damit Verweise stimmen):
1. ~~**Rezeptbilder**~~ entschieden: BFL-Fotos (Entscheidung 46).
2. ~~**Rezeptquelle langfristig**~~ entschieden: beides, kuratierte JSON-Dateien in Stapeln (Entscheidung 45)
   und Import per Claude API (Entscheidung 17).
3. ~~**Apple Developer Account / Signing**~~ entschieden: Entwicklerkonto der Schule (Entscheidung 40), Team in
   `Local.xcconfig` (Entscheidung 44).
4. **BLS-4.0-Lizenz:** Anfrage beim Max Rubner-Institut, ob abgeleitete Werte in ein öffentliches Repo dürfen.
   Empfehlung: nur bei Bedarf an Nährwerten stellen, bis dahin USDA (CC0).
5. **Authentizität prüfen:** Wer hakt die Rezept-Prüfliste ab? Empfehlung: du beim ersten Kochen, bei Zweifeln
   jemand aus der jeweiligen Küche.
6. **Parallele Timer (M13): ob und wann.** Drei der 24 Rezepte haben Wartezeiten neben dem Gerät ohne
   Timer (Abschnitt 3e). Der Umbau berührt Kochsitzung, AlarmKit, Live Activity, Siri, Editor und Import.
   Möglichkeiten: (a) als Nächstes nach M10, vor M11, und die drei Wartezeiten (Dal Tadka, Jeera-Reis,
   Chicken Adobo) als Nebentimer nachrüsten; (b) erst, wenn ein Rezept beim Kochen daran scheitert; (c) gar nicht, Nebenarbeit bleibt Text
   im Schritt. Empfehlung: (a), aber nur M13a und M13b; M13c folgt, sobald du im Editor oder beim Import
   einen Nebentimer vermisst.
7. ~~**TestFlight-Auslöser**~~ entschieden: bei jedem Push auf `main` (Entscheidung 50). Noch offen: einen
   übersprungenen Upload sichtbar machen (Hinweis in der Job-Zusammenfassung). Empfehlung: ja, damit ein grüner
   Lauf ohne Upload nicht wie ein erfolgreicher Upload aussieht.

## 10. Gauntlet-Loop: Umsetzung der restlichen Meilensteine

Ab M2 arbeitet Claude die Meilensteine selbstständig nacheinander ab. Jeder Meilenstein muss eine
feste Reihe von Prüfungen bestehen (den „Gauntlet“), bevor er nach `main` geht und der nächste beginnt.

### Reihenfolge
M2 Bibliothek und Rezeptansicht → M3 Kochmodus → M4 Hintergrund-Timer, Live Activity, Siri →
M5 Barrierefreiheit, iPad, Motion → M6 Rezept-Import → M7 Sprachmodus → M8 Evidenz-Datenbank → M9 Gesund umschreiben → M10 Rezeptbestand →
M11 Einkauf und Vorrat (Entscheidung 24).
Scheiben für die neuen Meilensteine: M8a Datenmodell und Katalog, M8b geprüfte Einstufungen, M8c Nährwerte;
M9a Umwandlung Ausgewogen in KitchenCore, M9b Ziele Blutdruck, Abnehmen, Low Carb, M9c Ansicht mit Zielwahl;
M10a Felder, M10b bis M10j je 3 Rezepte (ein Küchenraum pro Scheibe); M11a Logik, M11b App
mit Speicherung, Erinnerungen und Teilen; M13a parallele Timer in KitchenCore, M13b App, M13c Editor und
Import (Zeitpunkt: offene Entscheidung 6).
Große Meilensteine werden in Scheiben geteilt (je ein PR), z. B. M4a Timer und Mitteilungen, M4b Live Activity.

### Ablauf pro Scheibe
1. **Zuschnitt:** Ziel und Abnahme aus Abschnitt 8 holen, betroffene Skills laden (`app-architecture`,
   `liquid-glass`, `liquid-glass-motion`, `apple-motion-feel`, `swiftui-expert-skill`).
2. **Logik zuerst:** Alles ohne Bildschirm kommt nach `KitchenCore`, mit Tests.
3. **Oberfläche:** dünne Views, ein Screen-Modell pro Screen, Motion-Tokens, deutsche Texte.
4. **Gauntlet** (jede Stufe muss grün sein, sonst zurück zu 2 oder 3):
   - G1 lokal unter Linux: `swift build --build-tests`, `swift test`, `swift format lint --strict`
   - G2 Selbstreview des Diffs mit `/code-review` (Stufe high), Befunde beheben
   - G3 Checklisten: Review-Checkliste aus `app-architecture`, `liquid-glass/references/review-checklist.md`,
     Korrektheits-Checkliste aus `swiftui-expert-skill`
   - G4 PR (Draft), CI grün: `kitchencore-linux` und `app-ios` (Xcode 27, Simulator-Build)
   - G5 Doku: Status in Abschnitt 8, neue Entscheidungen in Abschnitt 9, Geräte-Prüfliste (unten)
   - G6 Merge nach `main`, Branch neu auf `main`
5. **Nächste Scheibe.** Ein Fehler, der nach drei Runden an derselben Stufe bleibt, wird gemeldet.

### Entscheidungen unterwegs
- **Umkehrbar und im Rahmen des Plans** (Benennung, Layout-Details, Reihenfolge innerhalb eines Meilensteins):
  Claude nimmt die Empfehlung, trägt sie in Abschnitt 9 ein und schickt eine kurze Info per Push-Nachricht.
- **Blockierend** (braucht dich: API-Schlüssel, Apple-Konto, Gerätetest, Änderung am Umfang, alles nach außen):
  Push-Nachricht mit Optionen und Empfehlung. Der betroffene Teil wartet, Claude arbeitet an unabhängigen
  Teilen weiter.

### Grenzen des Loops
In der Cloud gibt es kein Gerät. Glasdarstellung, Motion-Gefühl, Live Activity, Siri, Mikrofon und
Sprachmodell lassen sich nur kompilieren, nicht erleben. Was nur am Gerät prüfbar ist, landet in der
Geräte-Prüfliste. Der Loop endet, wenn M7 gemergt ist oder alles Verbleibende auf dich wartet.

**Zusatzstufe für Daten (M8 bis M10):** G1b Datenprüfung. Jede Zahl in der Evidenz-Datei wird gegen ihre
Quelle (DOI) geprüft, jedes Rezept gegen `validate` und den Lebensmittelkatalog. Die mechanische Prüfung
(Schema, Vollständigkeit, jede Datei, keine Stichproben) läuft als eigener Prüfauftrag mit vollständiger
Fehlerliste.

### Geräte-Prüfliste (iPhone 18)
- [ ] M2: Glas der Suchleiste, des Portionsreglers und des Start-Buttons wirkt über dem Farbverlauf (nicht flach)
- [ ] M2: Zoom-Übergang von der Rezeptkarte zur Rezeptansicht, Portionsregler mit Haptik
- [ ] M2: Dunkelmodus und Dynamic Type bis XXL in Bibliothek und Rezeptansicht
- [ ] M3: Ein Rezept komplett durchkochen: Wischen und Knöpfe, Gerätekonsole lesbar aus etwa 60 cm
- [ ] M3: Timer: Start, Pause, Zurücksetzen, Haptik beim Ablauf; Bildschirm bleibt an
- [ ] M3: Timer läuft nach App-Wechsel richtig weiter (Mitteilung im Hintergrund erst ab M4)
- [ ] M4a: Erlaubnis-Abfrage für Alarme beim ersten Timer-Start
- [ ] M4a: Timer klingelt bei gesperrtem iPhone und im Stumm-Modus; Countdown auf Sperrbildschirm und in der Dynamic Island
- [ ] M4a: Pause in der App nimmt den Countdown vom Sperrbildschirm, Fortsetzen zeigt ihn wieder; Zurücksetzen und Verlassen des Kochmodus entfernen ihn
- [ ] M4a: Ein abgelaufener Alarm klingelt weiter, auch wenn du den Kochmodus verlässt, bis du ihn stoppst
- [ ] M4b: Schritt-Anzeige auf Sperrbildschirm und Dynamic Island; Weiter und Zurück funktionieren ohne Entsperren
- [ ] M4b: Mit laufendem Timer stehen Schritt-Anzeige und Countdown sinnvoll nebeneinander (sonst Entscheidung 13 überdenken)
- [ ] M4c: „Hey Siri, nächster Schritt in Omni Cook“, „Wie lange noch in Omni Cook“, „Timer starten in Omni Cook“
- [ ] M5: Animationen bei 120 Hz: Portionsregler, Schrittwechsel per Knopf, Timer-Ziffern; nichts wirkt träge oder wackelt
- [ ] M5: App-Icon auf dem Homescreen (hell, dunkel)
- [ ] M5: iPad quer und hoch, auch im Split View: Kochmodus mit Leiste rechts; Größenwechsel bricht den Timer nicht ab
- [ ] M5: Dynamic Type in Bedienungshilfen-Größen: Rezeptkopf wächst mit, Konsolen-Kacheln stehen untereinander
- [ ] M5: VoiceOver durch Bibliothek, Rezeptansicht und Kochmodus
- [ ] M9c: Rezeptansicht: Menü „Original“ über dem Farbverlauf wirkt als Glas neben dem Portionsregler; Ziel wählen zeigt „Was sich ändert“ ohne Ruckeln
- [ ] M9c: Änderungsliste lesbar, Quelle aufklappbar, Nährwerte pro Portion stimmen mit der Zutatenliste überein; VoiceOver liest „X wird zu Y“
- [ ] M9c: „Kochen starten“ mit gewähltem Ziel kocht die Variante (Zutaten, Schrittzeiten, Hinweise)
- [ ] M10a: Bibliothek: Filter „Küche“ in der Leiste zeigt nur vorhandene Küchen, das Symbol ist gefüllt, solange ein Filter aktiv ist
- [ ] M10a: Rezeptansicht: Abschnitt „Herkunft“ mit Küche, Region, Quellen und Prüfpunkten, nur bei Rezepten mit diesen Angaben
- [ ] M10b: Dal Tadka, Jeera-Reis und Chana Masala einmal am Gerät kochen: Zeiten, Stufen und Wassermengen stimmen; Gewürze und Technik laut Prüfpunkten
- [ ] M10b: Jeera-Reis gart ohne Rühren: heizt der Omni Cook bei 100 °C ohne Drehung gleichmäßig, oder braucht es Linkslauf Stufe 1?
- [ ] M10b: Vollkornreis-Variante (Ausgewogen) mit 440 g Wasser und 33 Min: Reis gar, nichts angesetzt
- [ ] M10c: Grünes Curry, Tom Kha Gai und Pad Krapow am Gerät: Paste fein genug nach 40 s auf Stufe 9, Hähnchen bei Stufe 6 grob statt Brei, Kokosmilch flockt nicht
- [ ] M10d: Gà Kho Gừng: Karamell bei 160 °C bernsteinfarben, wie lange wirklich (Timer 7 Min ist Obergrenze); Chicken Adobo: Essig ohne Rühren aufkochen (Gerät heizt ohne Drehung?); Sayur Lodeh: Paste ohne Fasern, Kokosmilch flockt bei 90 °C nicht, Gemüse bissfest
- [ ] M10e: Mapo Tofu: Tofu bleibt bei Linkslauf Stufe 1 ganz; Tomaten-Rührei: Ei weich nach 3 Min bei 100 °C; Wolfsbarsch: 10 Min Dampf für 150-g-Filets, Öl bei 160 °C heiß genug zum Zischen
- [ ] M10f: Dashi: Kombu bei 60 °C ohne Rühren gleichmäßig warm, Katsuobushi sinkt bei 90 °C ab; Oyakodon: Ei nach 90 s bei 90 °C ohne Rühren halb gestockt; Misosuppe und Kimchi-Jjigae: Tofu bleibt bei Linkslauf Stufe 1 ganz
- [ ] M10g: Mercimek: heiße Suppe auf Stufe 9 pürieren ohne Spritzen; Kuru Fasulye: eingeweichte Bohnen nach 80 Min bei 100 °C weich, aber ganz; Mujaddara: Zwiebeln nach 25 Min bei 130 °C tief goldbraun, Reis und Linsen gar ohne Ansetzen
- [ ] M10h: Lobio: kochen eingeweichte Kidneybohnen bei 110 °C ohne Messbecher sichtbar sprudelnd (roh giftig, laut BfR 2024 mindestens 30 Min kochen), Schaum bleibt im Topf, nach weiteren 60 Min weich; Stufe 3 für 4 s zerdrückt grob; Chakhokhbili: Huhn nimmt bei 160 °C mit 1 EL Öl Farbe, Sauce dickt ohne Messbecher ein; Ajapsandali: Schmoren ohne Rühren brennt nicht an
- [ ] M10i: Pasta e ceci: Stufe 5 für 4 s lässt gut die Hälfte der Kichererbsen ganz, Ditalini kleben bei Linkslauf nicht an; Borschtsch: Rote Bete nach 8 Min bei 120 °C weich genug; Spanakorizo: Reis nach 18 Min saftig gar, Spinat brennt nicht an
- [ ] M10j: Tinga: Linkslauf Stufe 4 für 6 s zerzupft das Huhn faserig; Arroz rojo: Reis röstet bei 120 °C hell golden ohne anzusetzen, gart ohne Rühren gleichmäßig; Locro: Kürbis zerfällt nach 20 Min teilweise, Queso fresco wird in der heißen Suppe weich, ohne zu schmelzen; Arroz rojo mit 250 g Wasser plus Püree körnig
- [ ] M11b1: „Auf die Einkaufsliste“ in der Rezeptansicht plant das Rezept; Liste nach Bereichen, Abhaken mit Haptik; „Eingekauft“ bucht nur Abgehaktes in den Vorrat; „Fertig“ im Kochmodus bucht ab und „Rückgängig“ im Einkauf stellt es wieder her; Vorrat: Füllstand per Segment, Gramm und Mindestbestand per Stepper; Teilen als Text, etwa nach Bring!
- [ ] M11b2: „In Erinnerungen“ fragt einmal nach Zugriff, legt die Liste „Einkauf (Omni Cook)“ an, ein zweiter Export ersetzt die offenen Einträge statt sie zu verdoppeln, abgehakte bleiben; ohne Zugriff erscheint der Hinweis auf die Einstellungen
- [ ] Editor „Erkannt als“: Zutat zeigt das erkannte Lebensmittel, „Nicht erkannt“ in der Zutatenliste; Wahl von Hand bleibt nach Umbenennen und Sichern; „Automatisch nach dem Namen“ erkennt wieder neu
- [ ] Vegetarisch: Pad Krapow und Chakhokhbili öffnen mit Tofu, Wolfsbarsch im Original mit „Alternative: Tofu, fest“; Tofu bleibt bei Linkslauf Stufe 1 in 25 Min Schmoren ganz; Schalter in den Einstellungen; Einkaufsliste zeigt Tofu statt Hähnchen
- [ ] Einkaufs-Agent: „Teilen > Für Einkaufs-Agenten“ in Claude für Chrome (oder einen anderen Browser-Agenten) einfügen, bei REWE und einem zweiten Shop testen: Suchbegriffe treffen, Packungsgrößen passen, der Agent hält vor der Kasse und bei Sicherheitsabfragen an
- [ ] M13: Gerätetimer und zwei Nebentimer gleichzeitig: drei AlarmKit-Countdowns auf dem Sperrbildschirm, jeder klingelt einzeln; Stoppen eines Alarms lässt die anderen laufen
- [ ] M13: Pause eines Nebentimers nimmt nur dessen Countdown weg; Verlassen des Kochmodus entfernt alle nicht abgelaufenen
- [ ] M13: Timer-Liste in der Gerätekonsole aus etwa 60 cm lesbar; Tippen auf eine Zeile springt zum Schritt
- [ ] M13: „Wie lange noch in Omni Cook“ mit zwei laufenden Timern nennt beide, den früheren zuerst
- [ ] M6: API-Schlüssel in den Einstellungen eintragen und wieder entfernen
- [ ] M6: Import aus kopiertem Text und aus einem Link (https), Vorschau mit Prüfung, Speichern; eigenes Rezept erscheint oben in der Bibliothek, Löschen per langem Druck
- [ ] M6: Werte eines importierten Rezepts einmal am Gerät gegenprüfen
- [ ] M7: Beim ersten Kochmodus fragt iOS nach Mikrofon (und ggf. Spracherkennung); das deutsche Sprachmodell lädt, Statusanzeige zeigt „Ich höre zu“
- [ ] M7: Ein Rezept komplett per Sprache durchkochen: „weiter“, „zurück“, „nochmal“, „wie lange noch“, „Timer starten“, „Pause“, „welche Zutaten“, mit laufendem Gerät und Dunstabzug
- [ ] M7: Gespräch in der Küche (längere Sätze ohne „Omni“) löst nichts aus; die App reagiert nicht auf ihre eigene Stimme
- [ ] M7: „Mir fehlt der Lachs“ im Ingwer-Lachs nennt Kabeljau und Lachsforelle mit Menge für die gewählten Portionen
- [ ] M7: „Omni, kann ich statt Spinat Mangold nehmen?“ beantwortet das Sprachmodell kurz, mit Hinweis „KI-Antwort, ungeprüft“; ohne Apple Intelligence kommt ein klarer Hinweis
- [ ] M7: Mikrofon aus bleibt aus beim nächsten Rezept; App in den Hintergrund und zurück setzt das Zuhören fort; Antworten kommen aus dem Lautsprecher
- [ ] M7: Nach einem Anruf und nach dem Verbinden von AirPods hört die App wieder zu (Statusanzeige und ein „weiter“ prüfen)
- [ ] M12: Sprachprotokoll in den Einstellungen: nach einem Kochvorgang stehen die Sätze darin, Teilen als Text klappt, Löschen leert es
- [ ] M12: „Mir fehlt die Sojasauce“ im Ingwer-Lachs nennt Tamari und Fischsauce mit Menge
- [ ] M12: Neues Rezept über „+“ anlegen, mit zwei Zutaten und drei Schritten (einer mit Dampf), sichern und kochen
- [ ] M12: Mitgeliefertes Rezept bearbeiten: es entsteht eine eigene Kopie, die Ansicht wechselt auf die Kopie
- [ ] M12: Editor mit einer Hand am iPhone: Tastatur verdeckt nichts Wichtiges, Sortieren und Wischen zum Löschen funktionieren, Abbrechen fragt bei Änderungen nach
- [ ] M12: Zutaten per Schnellzeile („200 g Rote Linsen“, „½ TL Kurkuma“, „Salz“) und per eingefügter Liste aus einem Webrezept; Ergebnis stimmt
- [ ] M12: Schnellwahl für 120 °C, Stufe 5 und 3 Min mit je einem Tipp; Haptik beim Wählen; Schritt duplizieren per Wischen
- [ ] M12: Import aus Text, in der Vorschau „Bearbeiten“, eine Menge und eine Temperatur ändern, sichern: das geänderte Rezept steht oben in der Bibliothek; Abbrechen führt unverändert zur Vorschau zurück
