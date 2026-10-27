# Prompt: Rezeptbestand erweitern (10 Rezepte pro Küche)

Dieser Prompt erzeugt neue mitgelieferte Rezepte für ClaudeKitchen, jeweils **ein Stapel von 10 Rezepten für
genau eine Küche**. Für alle neun Küchen sind das neun Durchläufe. Jeder Stapel wird einzeln geprüft (Abschnitt 9)
und als eigener Pull Request eingereicht.

Kopiere alles ab „Auftrag“ in eine Session mit Zugriff auf das Repository und ersetze `<KÜCHE>` durch einen der
Werte aus Abschnitt 2.

---

## Auftrag

Schreibe 10 neue, traditionelle Rezepte der Küche `<KÜCHE>` für den TOKIT Omni Cook als JSON-Dateien in
`Sources/KitchenCore/Resources/Recipes/`. Lies vorher `CLAUDE.md`, `PLAN.md` (Abschnitt 3c und 6.2) und den Skill
`app-architecture`. Ändere keinen Swift-Code und keine Tests. Wenn ein Rezept eine Prüfung nicht besteht, änderst
du das Rezept, nie die Prüfung.

## 1. Was ein Rezept hier ist

- Die App steuert das Gerät nicht. Sie begleitet den manuellen Modus: Jeder Schritt sagt, was in den Topf kommt
  und welche Einstellung (Temperatur, Stufe, Laufrichtung, Zeit) der Mensch am Gerät wählt.
- Ein Rezept ist ein traditionelles Gericht aus einer der neun Küchen, auf den Omni Cook übertragen. Abwandlungen
  für das Gerät sind erlaubt, stehen aber offen in der Prüfliste (`authenticityChecks`).
- Grundportionen 2 bis 4, die Füllmenge von 2,2 l darf bei den Grundportionen nicht überschritten werden.

## 2. Küchen (`Cuisine` in `Sources/KitchenCore/RecipeOrigin.swift`)

| `cuisine` | Küchenraum | Tag-Beginn (Auswahl, siehe Abschnitt 5) |
|---|---|---|
| `india` | Indien | Indisch |
| `thailand` | Thailand | Thailändisch |
| `southeastAsia` | Vietnam, Indonesien, Malaysia, Philippinen | Vietnamesisch, Indonesisch, Malaysisch, Philippinisch |
| `china` | China | Chinesisch |
| `japanKorea` | Japan und Korea | Japanisch, Koreanisch |
| `turkeyLevant` | Türkei und Levante | Türkisch, Levantinisch, Libanesisch, Syrisch, Palästinensisch, Jordanisch |
| `georgia` | Georgien | Georgisch |
| `europe` | Mittelmeer und Osteuropa | Mediterran, Osteuropäisch, Griechisch, Italienisch, Spanisch, Portugiesisch, Französisch, Kroatisch, Ukrainisch, Polnisch, Ungarisch, Rumänisch, Bulgarisch |
| `mexicoPeru` | Mexiko und Peru | Mexikanisch, Peruanisch |

Verteile die 10 Rezepte über Regionen und Gerichtsarten (Suppe, Eintopf, Curry, Beilage, Gedämpftes, Ei,
Hülsenfrüchte, Fisch, Fleisch, Gemüse). Bei Küchenräumen mit mehreren Ländern sollen mehrere Länder vorkommen.

## 3. Das Gerät: TOKIT Omni Cook (`DeviceProfile.omniCook`)

Nur diese Werte gelten. Erfinde keine weiteren Grenzen, Programme oder Zubehörteile. Die Quelle ist
`Sources/KitchenCore/DeviceProfile.swift`; weicht sie von dieser Liste ab, gilt die Datei.

| Grenze | Wert | JSON |
|---|---|---|
| Temperatur | 35 bis 180 °C, in Schritten von 5 °C | `"heat": 100` |
| Dampf | eigener Wert statt Temperatur | `"heat": "steam"` oder `"program": "steam"` |
| Stufe Rechtslauf | 1 bis 10 | `"speed": 5` |
| Stufe Linkslauf | 1 bis 10 | `"speed": 1, "reverse": true` |
| Laufzeit pro Schritt | 1 Sekunde bis 99 Minuten (5940 s) | `"seconds": 720` |
| Füllmarke | 2,2 l (Gramm zählen als Milliliter) | |
| Zubehör | Dampfaufsatz, Korb, Rühraufsatz | `"accessory": "steamer"`, `"basket"`, `"whisk"` |
| Programme | `manual` (Standard, weglassen), `steam`, `knead`, `sousVide`, `yogurt`, `weigh` | `"program": "steam"` |

Regeln, die `DeviceProfile.validate` prüft:

- Dampf (`"heat": "steam"` oder `"program": "steam"`) braucht `"accessory": "steamer"` und darf keine Stufe haben.
- Temperatur, Stufe und Laufzeit müssen in den Bereichen oben liegen; Laufzeit größer als 0.
- Alle Zutaten im Topf zusammen bleiben unter 2,2 l. Ein Schritt mit `"freshPot": true` beginnt einen neuen,
  leeren Topf (zum Beispiel Beilage nach dem Umfüllen des Hauptgerichts). Was nur in den Dampfaufsatz kommt, zählt
  nicht zum Topf.
- Lebensmittel mit `mustBoil` im Katalog (zum Beispiel getrocknete Bohnen) müssen in den Schritten ab dem Zugeben
  insgesamt lange genug bei mindestens 100 °C kochen, sonst gibt es eine Warnung. Auch Warnungen sind für
  mitgelieferte Rezepte nicht erlaubt.
- Gerätewerte stehen nur im `setting` eines Schritts, nie als Zahl im Text, der dem Schrittfeld widerspricht.
- Es gibt **keine** Regel „über 60 °C keine hohe Stufe“. Sie ist nicht belegt und wurde verworfen.

Faustwerte aus den bestehenden Rezepten (keine Gerätegrenzen, nur Orientierung): Zerkleinern Stufe 5 für 5 bis
8 Sekunden ohne Hitze; Anschwitzen und Anrösten 110 bis 120 °C, Stufe 1 Linkslauf, 3 bis 5 Minuten; Köcheln 95 bis
100 °C, Stufe 1 Linkslauf. Linkslauf schont stückige Zutaten.

## 4. JSON-Schema

Eine Datei pro Rezept, Dateiname = `id` + `.json`. `id` in Kleinbuchstaben mit Bindestrichen, ohne Umlaute
(`ae`, `oe`, `ue`, `ss`).

### Rezept

| Schlüssel | Pflicht | Inhalt |
|---|---|---|
| `schemaVersion` | ja | immer `1` |
| `id` | ja | wie der Dateiname |
| `name` | ja | gebräuchlicher Name des Gerichts, Originalname in Umschrift, deutsche Übersetzung höchstens in Klammern |
| `tag` | ja | `"<Küche> · <Art>"`, siehe Abschnitt 5 |
| `baseServings` | ja | 2 bis 4 |
| `totalMinutes` | ja | Gesamtzeit inklusive Vorbereitung, ohne Einweichen über Nacht |
| `verified` | ja | immer `false` |
| `origin` | ja | `{ "cuisine": "<KÜCHE>", "region": "<Region>" }` |
| `references` | ja | mindestens ein Werk, siehe Abschnitt 6 |
| `authenticityChecks` | ja | 2 bis 4 Punkte, siehe Abschnitt 6 |
| `ingredients` | ja | Liste der Zutaten |
| `steps` | ja | 4 bis 10 Schritte |
| `variantOf` | nein | nur für gesunde Varianten eines bestehenden Rezepts, hier weglassen |

### Zutat

| Schlüssel | Pflicht | Inhalt |
|---|---|---|
| `id` | ja | kurz, eindeutig im Rezept, zum Beispiel `zwiebel`, `oel-tomate` |
| `name` | ja | deutscher Name, wie er auf der Einkaufsliste stehen soll |
| `food` | ja | ID aus `Sources/KitchenCore/Resources/Evidence/food-catalog.json` (Abschnitt 7) |
| `quantity`, `unit` | nein | Menge für `baseServings`; `unit` ist `g`, `Stk`, `Zehen`, `TL` oder `EL`. Ohne `quantity` heißt „nach Geschmack“ |
| `note` | nein | kurze Angabe neben der Menge, zum Beispiel „in Spalten“, „à 150 g“ |
| `scales` | nein | `false`, wenn die Menge mit den Portionen gleich bleibt (Lorbeerblatt, Wasser für den Dampf) |
| `eaten` | nein | `false` für alles, was vor dem Essen herausgenommen wird (Dampfwasser, Lorbeer, Zitronengras) |
| `substitutes` | nein | Ersatz: `{ "name": "...", "ratio": 1, "note": "..." }`, `ratio` größer 0, Name anders als das Original |

Jede Zutat muss in mindestens einem Schritt unter `ingredientIDs` stehen.

### Schritt

| Schlüssel | Pflicht | Inhalt |
|---|---|---|
| `id` | ja | `s1`, `s2`, ... |
| `phase` | ja | ein Wort oder zwei, zum Beispiel „Anschwitzen“, „Köcheln“, „Anrichten“ |
| `text` | ja | was der Mensch tut, 20 bis 160 Zeichen, ein oder zwei Sätze |
| `note` | nein | Begründung oder Hinweis, höchstens 200 Zeichen |
| `ingredientIDs` | nein | Zutaten, die in diesem Schritt in den Topf oder Aufsatz kommen |
| `setting` | nein | `heat`, `speed`, `reverse`, `seconds`, `program` (Abschnitt 3) |
| `accessory` | nein | `steamer`, `basket`, `whisk` |
| `freshPot` | nein | `true`, wenn der Schritt in einem leeren, sauberen Topf beginnt |

### Referenzbeispiel

So sieht ein fertiges Rezept aus (`tomaten-ruehrei.json`, unverändert aus dem Bestand):

```json
{
  "schemaVersion": 1,
  "id": "tomaten-ruehrei",
  "name": "Tomaten-Rührei (Fan Qie Chao Dan)",
  "tag": "Chinesisch · Hausmannskost",
  "baseServings": 2,
  "totalMinutes": 20,
  "verified": false,
  "origin": { "cuisine": "china", "region": "China" },
  "references": [
    { "title": "Every Grain of Rice", "author": "Fuchsia Dunlop", "year": 2012 }
  ],
  "authenticityChecks": [
    "Eier weich und großflockig gerührt, getrennt von den Tomaten",
    "Tomaten mit einer Prise Zucker gegart, bis sie Saft ziehen, dann Ei zurück",
    "Einfache Hausmannskost, mit Reis gegessen"
  ],
  "ingredients": [
    { "id": "eier", "name": "Eier", "food": "egg", "quantity": 4, "unit": "Stk", "note": "mit einer Prise Salz verquirlt" },
    { "id": "oel-ei", "name": "Rapsöl", "food": "canola-oil", "quantity": 1, "unit": "EL", "note": "für die Eier" },
    { "id": "tomaten", "name": "Tomate", "food": "tomato", "quantity": 3, "unit": "Stk", "note": "in Spalten" },
    { "id": "oel-tomate", "name": "Rapsöl", "food": "canola-oil", "quantity": 1, "unit": "EL", "note": "für die Tomaten" },
    { "id": "zucker", "name": "Zucker", "food": "sugar", "quantity": 1, "unit": "TL" },
    { "id": "salz", "name": "Salz", "food": "salt" },
    { "id": "fruehlingszwiebel", "name": "Frühlingszwiebel", "food": "spring-onion", "quantity": 1, "unit": "Stk", "note": "in Ringen" }
  ],
  "steps": [
    { "id": "s1", "phase": "Rührei", "text": "Öl und verquirlte Eier in den Topf geben und zu weichem, großflockigem Rührei stocken lassen.",
      "note": "Ohne Messbecher und ohne Rühren, damit große Flocken entstehen. Nach der Hälfte einmal mit dem Spatel vom Boden lösen und wenden. Lieber etwas zu früh aufhören, es zieht nach.",
      "ingredientIDs": ["oel-ei", "eier"],
      "setting": { "heat": 100, "seconds": 180 } },
    { "id": "s2", "phase": "Umfüllen", "text": "Rührei auf einen Teller geben. Topf kurz auswischen." },
    { "id": "s3", "phase": "Tomaten", "text": "Öl, Tomaten, Zucker und Salz in den Topf geben und garen, bis die Tomaten Saft ziehen.",
      "ingredientIDs": ["oel-tomate", "tomaten", "zucker", "salz"],
      "setting": { "heat": 110, "speed": 1, "reverse": true, "seconds": 300 }, "freshPot": true },
    { "id": "s4", "phase": "Zusammen", "text": "Rührei zurück in den Topf geben und kurz unterheben.",
      "note": "Nur kurz, damit das Ei in Flocken bleibt.", "ingredientIDs": ["eier", "oel-ei"],
      "setting": { "heat": 90, "speed": 1, "reverse": true, "seconds": 60 } },
    { "id": "s5", "phase": "Anrichten", "text": "Mit Frühlingszwiebel bestreuen und mit Reis servieren.",
      "ingredientIDs": ["fruehlingszwiebel"] }
  ]
}
```

Für Dampf siehe `gedaempfter-wolfsbarsch.json`, für eingeweichte Hülsenfrüchte `lobio.json`.

## 5. Tag, Region, Name

- `tag` hat zwei oder drei Teile, getrennt durch ` · ` (Leerzeichen, Mittelpunkt U+00B7, Leerzeichen):
  `"<Küche> · <Art>"` oder `"<Küche> · <Art> · <Hinweis>"`, zum Beispiel `"Türkisch · Suppe"` oder
  `"Georgisch · Bohneneintopf · über Nacht einweichen"`.
- Der erste Teil ist ein Adjektiv aus der Tabelle `tagAdjectives` in
  `Tests/KitchenCoreTests/RecipeQualityTests.swift` und gehört zur `cuisine` des Rezepts. Ein neues Adjektiv
  (etwa „Sizilianisch“) gehört mit Begründung in den Pull Request und in diese Tabelle, nicht still ins Rezept.
- `region` ist Pflicht: ein Land, wenn das Gericht im ganzen Land verbreitet ist („Japan“, „Türkei“), sonst eine
  Region („Punjab“, „Sichuan“, „Kanton“, „Imeretien“, „Java“). Ein Land muss zur Küche passen, und wenn das
  Tag-Adjektiv ein Land nennt („Koreanisch“), muss eine Länder-Region dasselbe Land sein („Korea“).
- Schreibe jede Region so wie im Bestand. Vorhandene Schreibweisen: `grep -h '"region"'
  Sources/KitchenCore/Resources/Recipes/*.json | sort | uniq -c`.

## 6. Quellen und Recht (PLAN.md, Abschnitt 3c)

- **Alle Texte selbst formulieren.** Kein Satz, keine Schrittfolge im Wortlaut und kein Foto aus Blogs,
  Kochbüchern, Videos oder Datensätzen wie RecipeNLG. Zutatenlisten mit Mengen sind in der Regel nicht geschützt,
  ausformulierte Anleitungen schon.
- **Quellen nur zitieren:** `references` nennt Standardwerke der Küche oder Kulturerbe-Einträge (UNESCO) mit
  `title`, `author` und `year`, bei Webquellen `url`. Nenne nur Werke, von denen du sicher weißt, dass es sie gibt.
  Keine erfundenen Titel, Jahre oder Seitenzahlen.
- Wikibooks (CC BY-SA) nur, wenn Namensnennung und Share-Alike für die Datei gelten; im Zweifel nicht verwenden.
- **Authentizität kannst du nicht belegen, nur plausibel machen.** Deshalb `verified: false` und 2 bis 4
  `authenticityChecks`: konkrete Punkte, die jemand aus der Küche abhaken kann (Gewürze, Technik, Beilage,
  Serviertemperatur). Jede Abwandlung für das Gerät oder den deutschen Supermarkt steht dort offen, etwa
  „Rapsöl statt Senföl ist eine Abwandlung; traditionell Senföl“.

## 7. Zutaten und Lebensmittelkatalog

- Jede Zutat bekommt ein `food` aus `Sources/KitchenCore/Resources/Evidence/food-catalog.json`. Die IDs liefert
  `python3 -c "import json; print('\n'.join(f['id'] + '  ' + f['name'] for f in json.load(open('Sources/KitchenCore/Resources/Evidence/food-catalog.json'))['foods']))"`.
- Zutaten in `Stk`, `Zehen`, `TL` oder `EL` brauchen ein Gewicht im Katalog (Feld `gramsPerUnit`), sonst schlägt
  `FoodCatalogTests` fehl. Im Zweifel in `g` angeben.
- **Fehlt ein Lebensmittel im Katalog, erfinde keinen Eintrag und keine Nährwerte.** Schreibe das Rezept nicht
  in diesen Stapel, sondern liste es mit den fehlenden Lebensmitteln unter „Neue Lebensmittel zur Prüfung“ im
  Pull Request: deutscher Name, Gruppe und Rolle als Vorschlag, gesuchter USDA-FoodData-Central-Eintrag. Ein
  Mensch ergänzt den Katalog in einem eigenen Pull Request, danach folgt das Rezept.
- Ersatz (`substitutes`) nur, wo er im Alltag hilft, mit ehrlicher `note` („milder“, „weniger rauchig“).

## 8. Sprache und Stil

- Alle Texte für Menschen auf Deutsch, im Ton der bestehenden Rezepte: knapp, Imperativ ohne „Sie“
  („Zwiebeln in den Topf geben“), keine Werbesprache.
- **Keine Gedankenstriche:** kein Geviertstrich (U+2014), kein Halbgeviertstrich (U+2013) und kein Bindestrich
  mit Leerzeichen davor und danach als Ersatz. Nimm Komma, Doppelpunkt, Semikolon oder einen neuen Satz.
- Typografische Anführungszeichen „so“, Zahlen mit Einheit und Leerzeichen („3 Min“, „120 °C“).
- **Kein Gericht doppelt.** Prüfe vorher, was es schon gibt:
  `python3 -c "import json,glob; print('\n'.join(sorted(json.load(open(f))['name'] for f in glob.glob('Sources/KitchenCore/Resources/Recipes/*.json'))))"`.
  Auch eine andere Schreibweise desselben Gerichts gilt als doppelt (Groß- und Kleinschreibung, Akzente,
  Bindestriche und Klammerzusätze zählen nicht). Bestand bei Erstellung dieses Prompts (30 Rezepte):
  Ajapsandali, Arroz rojo, Borschtsch, Chakhokhbili, Chana Masala, Chicken Adobo, Dal Tadka, Gà Kho Gừng,
  Grünes Curry mit Hähnchen, Gedämpfter Wolfsbarsch, Ingwer-Lachs mit Pak Choi, Jeera-Reis,
  Kichererbsen-Spinat-Curry, Kimchi-Jjigae, Kuru Fasulye, Lobio, Locro de zapallo, Mapo Tofu, Mercimek Çorbası,
  Misosuppe mit Tofu und Wakame, Mujaddara, Oyakodon, Pad Krapow Gai, Pasta e ceci, Sayur Lodeh, Spanakorizo,
  Tinga de pollo, Tom Kha Gai, Tomaten-Rührei (Fan Qie Chao Dan), Zitronen-Linsen-Eintopf. Vermeide auch
  Gerichte, die einem davon nur dem Namen nach ausweichen (etwa „Chana Palak“ neben dem Kichererbsen-Spinat-Curry).

## 9. Stapel prüfen

Nach jedem Stapel im Repository-Ordner:

```bash
swift build --build-tests
swift test
swift format lint --recursive Sources Tests
```

Gezielt nur die Rezeptprüfungen:

```bash
swift test --filter "RecipeQualityTests|RecipeLibraryTests|FoodCatalogTests|NutritionTests"
```

Alle Tests müssen grün sein. Schlägt ein Test fehl, korrigiere das Rezept und prüfe erneut. Danach ein Branch
und ein Pull Request pro Stapel, im Text: Liste der 10 Gerichte mit Region, verwendete Quellen, offene Punkte
der Prüflisten und gegebenenfalls „Neue Lebensmittel zur Prüfung“.

## 10. Selbstprüfung vor der Abgabe

Gehe für **jedes** Rezept die Liste durch. Die Punkte entsprechen den Tests in
`Tests/KitchenCoreTests/RecipeQualityTests.swift`, `RecipeLibraryTests.swift`, `FoodCatalogTests.swift` und
`NutritionTests.swift`.

- [ ] Dateiname gleich `id`, `id` kommt im Bestand noch nicht vor.
- [ ] `schemaVersion` ist 1, `verified` ist `false`.
- [ ] `origin` mit passender `cuisine` und nicht leerer `region`; Region im Bestand gleich geschrieben.
- [ ] Ein Land als Region gehört zur Küche und passt zum Land des Tag-Adjektivs.
- [ ] `tag` hat zwei oder drei Teile mit ` · `, der erste ist ein Adjektiv aus `tagAdjectives` dieser Küche.
- [ ] Mindestens eine Referenz mit Titel und Autor (oder URL), Jahr plausibel, das Werk gibt es wirklich.
- [ ] Mindestens zwei konkrete `authenticityChecks`, Abwandlungen offen benannt.
- [ ] Kein Text abgeschrieben, alles selbst formuliert.
- [ ] Gericht noch nicht im Bestand, auch nicht in anderer Schreibweise.
- [ ] 4 bis 10 Schritte; jeder Schritttext 20 bis 160 Zeichen, jede Notiz höchstens 200 Zeichen, jede Phase
  nicht leer.
- [ ] Kein Geviertstrich, kein Halbgeviertstrich, kein „ - “ in Name, Tag, Region, Zutaten, Ersatz, Schritten,
  Notizen und Prüfliste.
- [ ] Jede Zutat hat ein `food` aus dem Katalog und taucht in mindestens einem Schritt auf; Stück- und
  Löffelangaben sind im Katalog wägbar.
- [ ] Jeder Ersatz hat einen eigenen Namen und `ratio` größer 0.
- [ ] Alle Einstellungen in den Grenzen aus Abschnitt 3; Dampf nur mit Dampfaufsatz und ohne Stufe.
- [ ] Füllmenge unter 2,2 l bei den Grundportionen; `freshPot` gesetzt, wo ein neuer Topf beginnt.
- [ ] Hülsenfrüchte mit `mustBoil` kochen lange genug bei mindestens 100 °C.
- [ ] `DeviceProfile.validate` ohne Fehler und ohne Warnung (`swift test` grün).
- [ ] `swift format lint --recursive Sources Tests` ohne Meldung.
