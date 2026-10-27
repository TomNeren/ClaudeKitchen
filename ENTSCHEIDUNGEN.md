# ClaudeKitchen: Entscheidungen

Stand: 27.10.2026. Zusammengetragen aus allen ClaudeKitchen-Sessions in der Cloud und auf dem Mac (Remote Control), dazu aus `PLAN.md` und der Git-Historie.

- Die nummerierte, verbindliche Liste steht in `PLAN.md` §9 (Nr. 1 bis 40). Sie wird hier nach Themen geordnet und nur kurz genannt.
- Ausführlich stehen hier die Entscheidungen, die nur in Sessions fielen und nie in `PLAN.md` landeten. Sie sind mit **(neu)** markiert.
- Quellen nennt die Spalte „Session“, die Kürzel sind am Ende erklärt.
- „Loop“ heißt: Claude hat im Gauntlet-Loop selbst entschieden. Solche Entscheidungen sind umkehrbar.

## 1. Vorgeschichte: Gerät und Fernsteuerung (11.10. bis 23.10.)

| Datum | Entscheidung | Begründung, Alternative | Session |
|---|---|---|---|
| 11.10. | **(neu)** Für die Fernsteuerung des TOKIT Omni Cook wird der App-Verkehr mit mitmproxy mitgeschnitten (Option 3). | Es gibt keinen bekannten offenen Weg, das Gerät hängt am Dienst „CookNJoy“. | TOK |
| 12.10. | **(neu)** Fernsteuerung verworfen. | Die Sicherheitssperren der App (apk-mitm, Netzwerkcode) wurden nicht umgangen. | TOK |
| 12.10. | **(neu)** Umbau am Gerät verworfen. | Die Sperren bleiben, und Heizung und Messer sind ein Risiko. | TOK |
| 12.10. | **(neu)** Stattdessen entsteht eine eigene Kochführung für den manuellen Modus, mit klaren Rezepten statt Tassenangaben und doppelten Schritten. | Daraus wurde die App (siehe `PLAN.md` §6.2). | TOK |
| 12.10. | Herstelleranfrage an TOKIT (API, Rezeptimport, Beta), auf Englisch. | Verschickt laut `PLAN.md` §9 Nr. 4, Antwort steht aus. | TOK, PLAN |
| 18.10. | **(neu)** Ziel der Küche: wenig Aufwand, wenig Kohlenhydrate, voller Geschmack, indisch, asiatisch, mediterran. | Longevity-Recherche: Mediterran ist am besten belegt, Blue Zones sind nur Beobachtungsdaten. | TOK |
| 23.10. | **(neu)** Drei Startrezepte (Zitronen-Linsen-Eintopf, Kichererbsen-Spinat-Curry, Ingwer-Lachs mit Pak Choi), Gerätewerte aus dem Handbuch. | Diese Kochführung ist das Artifact, aus dem das Repo entstand. | TOK |
| 23.10. | Keine Regel „über 60 °C keine hohe Stufe“. | Sie stammt aus der Vorläufer-Session und ist nicht belegt (`PLAN.md` §9 Nr. 6). | TOK, PLAN |

## 2. Umfang und Grundsätze

| Datum | Entscheidung | Begründung, Alternative | Session |
|---|---|---|---|
| 25.10. | Nur für den Eigengebrauch, kein App Store (Nr. 1). | Markenrecht und Store-Prüfung entfallen. | APP |
| 25.10. | Die App steuert das Gerät nicht, sie begleitet den manuellen Modus. | Siehe Abschnitt 1. | APP |
| 25.10. | Dampfaufsatz ist vorhanden, Dampfrezepte gehören in den Bestand (Nr. 3). | | APP |
| 25.10. | Zielgerät iPhone 18, Sprachmodus mit Dauerzuhören (Nr. 7). | | APP |
| 25.10. | „Gesund“ ist wählbar: Ausgewogen (DGE 2024) als Standard, dazu Blutdruck, Abnehmen, Low Carb (Nr. 25). | Low Carb gilt als Vorliebe, nicht als gesünder. | APP, GRD |
| 26.10. | Vegetarisch als Standard: Fleisch wird Tofu, Fisch und tierische Würzen bleiben mit Alternative (Nr. 37). | DGE 2024. | GRD |

## 3. Plattform, Technik, Architektur

| Datum | Entscheidung | Begründung, Alternative | Session |
|---|---|---|---|
| 23.10. | **(neu)** Aufbau aus `KitchenCore` (Package, testbar unter Linux) und SwiftUI-App getrennt. | In der Cloud gibt es kein Xcode. | CLD |
| 23.10. | Nur iOS 27, keine Fallbacks, Motion hochwertig (Nr. 2). | | CLD |
| 23.10. | **(neu)** Swift 6.4.1 fest eingepinnt, `swift-tools-version: 6.4`. | Erst von Grund auf testen, dann Setup-Skript und CI. | CLD |
| 23.10. | **(neu)** Skills nur im Repo (`.claude/skills/`), nicht global: eigene Architektur, Liquid Glass, Motion, SwiftUI von Antoine van der Lee. | `swiftui-macos` entfernt. Verworfen: `superagents-lab/xcode27-skills`, weil ohne Lizenz. | CLD |
| 23.10. | **(neu)** Doppelte Skripte in `liquid-glass-motion` gelöscht. Apples Xcode-27-Skills sollen über eine Mac-Session exportiert werden (Variante A). | Export ist noch nicht belegt. | CLD |
| 25.10. | Eigene Rezepte als JSON in Application Support statt SwiftData (Nr. 18). | Einfacher, keine Migrationen, exportierbar. | APP |
| 26.10. | **(neu)** Signing: `DEVELOPMENT_TEAM` aus der ignorierten `App/Config/Local.xcconfig` (PR #17). Gerät per WLAN über Xcode bespielen. | Verworfen: Umgebungsvariable, weil XcodeGen `${DEVELOPMENT_TEAM}` sonst wörtlich ins Projekt schreiben kann. | CLD |
| 27.10. | **(neu)** Nur iPhone und iPad. Mac (Designed for iPad), Apple Vision und Catalyst sind in `App/project.yml` abgeschaltet (PR #41). | | TFL |
| 27.10. | **(neu)** Deprecations von iOS 27 im Sprachcode durch die neuen APIs ersetzt (`LanguageModelError`, `installAudioTap`), Verhalten unverändert, keine Fallbacks (PR #42). | Nebenbei behoben: Der alte `catch` griff nie. | IOS |

## 4. CI, Repo, Cloud-Umgebung

| Datum | Entscheidung | Begründung, Alternative | Session |
|---|---|---|---|
| 23.10. | **(neu)** CI erst auf einem eigenen Mac-Runner (`kitchen-mini`). | Die GitHub-Abrechnung war blockiert. Die Jobs hingen, weil der Runner am Repo `KID` registriert war. | CLD |
| 24.10. | **(neu)** Der Runner sollte unter eigenem Benutzer `gh-runner` laufen. Alternative: GitHub-Organisation für mehrere Repos. | Überholt durch die nächste Zeile. | CLD |
| 25.10. | Repo öffentlich, CI auf gehosteten GitHub-Runnern mit `contents: read` (Nr. 5). | Kostenlos für öffentliche Repos. | CLD |
| 25.10. | Nie ein selbst gehosteter Runner für Pull Requests. | Fork-PRs könnten Code auf dem Mac ausführen. Steht in `CLAUDE.md`. | CLD |
| 25.10. | Kein Geheimnis ins Repo, API-Schlüssel nur in der Keychain. | Repo ist öffentlich. | APP |
| 26.10. | **(neu)** Setup-Skript ohne `swiftly`: Direktdownload von download.swift.org mit gpg-Prüfung, bis zu 5 Wiederholungen, kein Abbruch beim Start. Prüft beide Schreibweisen des Ordners. | Ursache: einmaliges 403 von Apples CDN. | CLD |
| 26.10. | **(neu)** Netzwerk-Freigaben für deutsche und französische Supermärkte in der Cloud-Umgebung ergänzt. | Für die Shop-Recherche. Sind noch aktiv. | SUP |

## 5. Kochmodus, Timer, Sprache, Siri

Alle aus APP, vom 25.10., Einzelheiten in `PLAN.md` §9.

- Portionen 1 bis 8, zusätzlich durch die Füllmarke begrenzt (Nr. 8, Loop).
- Ein laufender Timer bleibt beim Schrittwechsel erhalten (Nr. 10, Loop).
- Mit „Bewegung reduzieren“ Überblendung, kein Wischen (Nr. 11, Loop).
- Timer im Hintergrund über AlarmKit (Nr. 12, Loop).
- Zwei Live Activities: Schritt mit Knöpfen und AlarmKit-Countdown (Nr. 13, Loop).
- Siri und Knöpfe wirken nur bei offenem Kochmodus (Nr. 14, Loop).
- Motion ohne Nachschwingen, 0,3 bis 0,4 s, Timer-Ziffern 0,25 s (Nr. 15, Loop).
- iPad mit Bedienleiste rechts (Nr. 16, Loop).
- **(neu)** Der Sprachmodus ist ein Gespräch mit Rückfragen zum nächsten Schritt und zu Ersatzzutaten, nicht nur Vorlesen.
- Regeln für das Dauerzuhören mit „Omni“ (Nr. 20).
- Freie Fragen über Apples Sprachmodell auf dem Gerät (Nr. 21).
- Zuhören startet mit dem Kochmodus (Nr. 22).
- Sprachbefehle gehen denselben Weg wie Siri (Nr. 23).
- Sprachprotokoll ist an (Nr. 29).
- Ersatzlisten für die Startrezepte (Nr. 30).
- Parallele Timer als Meilenstein M13 entworfen (PR #15). Ob und wann gebaut wird, ist offen (siehe unten).

## 6. Import, Editor, Verbessern mit Claude

| Datum | Entscheidung | Begründung, Alternative | Session |
|---|---|---|---|
| 25.10. | Rezept-Import über die Claude Messages API mit eigenem API-Schlüssel (Nr. 17). | Ein Claude-Abo ist für eigene Apps nicht zugelassen, das Agent SDK läuft nicht auf iOS. | APP |
| 25.10. | Kein Editor in M6 (Nr. 19). | Überholt durch M12. | APP |
| 25.10. | Rezept-Editor für das Handy (Nr. 31). | | APP |
| 26.10. | **(neu)** Editor zeigt „Erkannt als“ und korrigiert das Lebensmittel einer Zutat (PR #36). | | GRD |
| 27.10. | Ein importiertes Rezept lässt sich vor dem Speichern bearbeiten (PR #40, `PLAN.md` §9 Nr. 41). | Behebt Fehler, die das Speichern blockieren, ohne neuen API-Aufruf. | APP |
| 27.10. | **(neu)** „Mit Claude verbessern“ (Phase 2) wird voll gebaut. Eine Variante muss `DeviceProfile.validate`, die Zutatenprüfung und den Lebensmittelkatalog bestehen. Der Nutzer speichert oder verwirft sie. | | LP2 |
| 27.10. | **(neu)** Phase 2 bleibt im PR der Startseite, als eigener Commit. | Verworfen: eigener Branch. Der Code ist getestet und ohne API-Schlüssel unsichtbar. | SBF |

## 7. Gesund umschreiben und Evidenz

Alle Loop oder APP vom 25. und 26.10., Einzelheiten in `PLAN.md` §9.

- Reihenfolge nach M7: M8, M9, M10, M11 (Nr. 24).
- Würzen und Aromabasis sind unantastbar (Nr. 26).
- Nährwerte aus USDA FoodData Central, CC0 (Nr. 28).
- Blutdruck darf salzarme Würzpaare tauschen (Nr. 33).
- Kochpflicht für rohe Bohnen nach BfR 2024 (Nr. 34).
- Zutaten werden über Namen und Aliase zugeordnet (Nr. 35).

## 8. Rezeptbestand und Qualität

| Datum | Entscheidung | Begründung, Alternative | Session |
|---|---|---|---|
| 26.10. | Neun Küchenräume mit je 3 Rezepten (Nr. 32). | | APP, GRD |
| 27.10. | **(neu)** Etwa 90 weitere Rezepte, 10 je Küche. Zuerst Qualitätswächter als Tests, dann der Prompt `Prompts/rezepte-erweitern.md` (PR #43). | Bisherige Wächter prüften nicht: Herkunft, Gedankenstriche, Schrittzahl, Tag-Format, Dubletten. | RWA, LP1 |
| 27.10. | **(neu)** Die Qualitätsregeln im Einzelnen. | | RWA |
| 27.10. | **(neu)** Bei Bestandsrezepten werden die Daten ergänzt, die Tests nicht aufgeweicht. | | RWA |
| 27.10. | **(neu)** Der Ingwer-Lachs bleibt eine eigene Kreation ohne Herkunft, über die Ausnahmeliste `ownCreations` im Test. | Verworfen: ein JSON-Feld `ownCreation`, weil eine Schemaänderung für ein Rezept zu viel ist. Ebenso verworfen: „Herkunft darf fehlen“, weil erzeugte Rezepte sonst unbemerkt durchkämen. | RWA |

Die Qualitätsregeln aus PR #43:

- Herkunft mit Region, mindestens eine Quelle, mindestens zwei Prüfpunkte.
- `verified` ist `false`.
- Keine Gedankenstriche.
- 4 bis 10 Schritte, Schritttext 20 bis 160 Zeichen.
- Tag in der Form „Küche · Art“.
- Keine Dubletten.

## 9. Einkauf und Vorrat

| Datum | Entscheidung | Begründung, Alternative | Session |
|---|---|---|---|
| 26.10. | Einkauf und Vorrat in KitchenCore (Nr. 36). | | GRD |
| 26.10. | Keine REWE-Anbindung über inoffizielle Schnittstellen (Nr. 27, 38). | App 6.1.3, Kundenkonto 3.4 und 1.11. Bot-Schutz. Amazon Fresh ist in Deutschland seit 14.12.2024 eingestellt. | GRD |
| 26.10. | Shopunabhängiger Einkaufs-Agent mit neutralen Suchbegriffen und `AgentBrief` (Nr. 39). | Verworfen: nur Suchbegriffe, oder auf eine Antwort von REWE warten. | GRD |
| 26.10. | **(neu)** Freundliche E-Mail an REWE, der Entwurf ist geliefert. | Eine Antwort steht aus. | GRD |
| 26.10. | **(neu)** Knuspr liefert nicht nach Lörrach, das Thema ist vorerst erledigt. | | SUP |
| 26.10. | **(neu)** Kein inoffizieller Leclerc-MCP (Empfehlung der Session). | Er umgeht den Bot-Schutz. Carrefour hat eine offizielle ChatGPT-App, aber keinen Markt in der Nähe. | SUP |

## 10. Startseite, Bilder, Kochprotokoll

Alle vom 27.10.

| Entscheidung | Begründung, Alternative | Session |
|---|---|---|
| **(neu)** „Landing Page“ heißt Startseite der App, nicht Webseite. | | LP1 |
| **(neu)** Variante A: Bildband mit zwei gegenläufigen Reihen, darunter eine Liste mit Fotos. | Verworfen: B, weil Fotos statt Badges zu wenig aufwerten. Ebenso verworfen: reines Fotoraster, weil Dauer und Portionen schlechter überblickbar sind. | LP1 |
| **(neu)** Rezeptbilder mit BFL FLUX.2 pro, erzeugt über `Scripts/generate_recipe_images.py`. Damit ist die offene Entscheidung 1 in `PLAN.md` beantwortet. | Verworfen: Gemini, weil weniger fotorealistisch bei Essen. Ebenso verworfen: Canva, weil uneinheitlich und schlecht skriptbar. | LP1 |
| **(neu)** Alle 27 fehlenden Bilder im Stil der drei Probebilder erzeugen. | Alternative war, vorher den Stil anzupassen. | SBF |
| **(neu)** Kochprotokoll (`CookLog`, `cooklog.json`) mit optionaler Bewertung 1 bis 5 und Notiz. Kapsel dunkel ohne Glas, weil sie Inhalt ist und keine Bedienung. | Verworfen: nur das Datum speichern, weil dann die Grundlage zum Verbessern fehlt. | LP1, LP2 |

## 11. Verteilung: TestFlight und Bundle-ID

| Datum | Entscheidung | Begründung, Alternative | Session |
|---|---|---|---|
| 26.10. | TestFlight über das Entwicklerkonto der Schule. Upload bei jedem Push auf `main`, nie bei PRs. Secrets nur im Environment `testflight` (Nr. 40). | Der Nutzer ist einziger Nutzer, ein Umzug geht per App-Transfer. | GRD |
| 27.10. | **(neu)** Bundle-ID `com.tomren.claudekitchen`, Widget `…claudekitchen.widgets`. | Verworfen: `de.tomneren.*`. Einheitlich mit den anderen Apps, nach dem Anlegen nicht mehr änderbar. | TFL |

## 12. Arbeitsweise

| Datum | Entscheidung | Begründung, Alternative | Session |
|---|---|---|---|
| 25.10. | **(neu)** Gauntlet-Loop: Claude setzt die Meilensteine selbst um. | Umkehrbares entscheidet Claude und trägt es ein. Blockierendes geht per Push-Nachricht mit Optionen an den Nutzer (`PLAN.md` §10). | APP |
| 26.10. | **(neu)** Eine Session übernimmt alle Merges nach `main`. | So gibt es keine Konflikte zwischen parallelen Sessions. | GRD |
| 27.10. | **(neu)** Zwei Sessions nie im selben Ordner arbeiten lassen. Die Zwischenstand-Session hielt still. | Sie hätten sich gegenseitig Dateien überschrieben. | ZWS |
| 27.10. | **(neu)** PR #44 mit Merge-Commit gemergt, ohne auf die CI zu warten. | Empfohlen war Warten, weil `main` TestFlight auslöst. Die CI war danach grün. | SBF |
| 27.10. | **(neu)** Lokale und Cloud-Gruppe „ClaudeKitchen“ lassen sich nicht zusammenführen. | Empfehlung: neue Sessions nur in der Cloud-Gruppe, Erledigtes archivieren. Die Umbenennung in „ClaudeKitchen Cloud“ ist vorgeschlagen, aber unbeantwortet. | APP, ZWA |

## 13. Noch offen

Aus `PLAN.md` §9 „Offen“, ergänzt um den Stand aus den Sessions.

1. **Rezeptbilder:** erledigt, mit BFL (Abschnitt 10). `PLAN.md` sollte das nachtragen.
2. **Rezeptquelle langfristig:** faktisch beides, kuratierte JSON-Dateien plus Import. Dazu kommt der Prompt für 90 Rezepte.
3. **Signing:** faktisch entschieden mit dem Schulkonto (Nr. 40).
4. **BLS-4.0-Lizenz:** offen. Bis dahin gilt USDA.
5. **Authentizität prüfen:** offen. Empfehlung: Der Nutzer prüft beim ersten Kochen.
6. **Parallele Timer M13:** offen. Empfehlung: (a), also M13a und M13b bauen.
7. **(neu)** Upload nur bei Tags statt bei jedem Push, und ein übersprungener Upload soll sichtbar werden. Vorgeschlagen, unbeantwortet (TFL).
8. **(neu)** Sollen die Netzwerk-Freigaben für die Supermärkte wieder entfernt werden? Unbeantwortet (SUP).

## Quellen (Sessions)

| Kürzel | Titel | Ort | ID |
|---|---|---|---|
| TOK | Tokio Omni Fernsteuerung und Rezepte | lokal | session_01Ftc5SUjJ2DfzPH3im9tZW1 |
| CLD | Cloud-Umgebung Setup | Cloud | session_01YX6qkmS9y1wW7tVZ7W8gZp |
| APP | App-Aufbau Plan | Cloud | session_0167th8KuWn8iHkaCeuphkaq |
| GRD | Gesunde Rezepte Datenbank | Cloud | session_01CGQrhkCBUCXJy8HmiW2gJn |
| SUP | Supermarkt online-Shop Vergleich | Cloud | session_01PjUqXVer8PJWnL9WeGTL63 |
| TFL | TestFlight Ablauf | Cloud | session_01JDMuuKKeH5aJ2Ehsco9MQf |
| IOS | Fix iOS 27 deprecation warnings | Cloud | session_01JDMuuJihaFpCxMm9oC5a3r |
| ZWA | Zwei Abschnitte zusammenführen | Cloud | session_01JDMuuJhinf7KtyQqy4zvQ5 |
| RWA | Rezept-Wächter und Prompt für 90 neue Rezepte | lokal | session_01JDMuuKHwq8QCLTvSMeJPh8 |
| LP1 | Landing Page mit Bildern für Rezepte (früh) | lokal | session_01JDMuuMHQPQXcURK4nLQYC4 |
| LP2 | Landing Page mit Bildern für Rezepte (Fork) | lokal | session_01JDMuuLuv4eLf8fSFgLq7Y4 |
| SBF | Startseite Bildband fortsetzen | lokal | session_01JDMuuK1cZgcPvMppkGtp6T |
| ZWS | Zwischenstand Startseite | lokal | session_01JDMuuKYMjzLdtQEkc6vSNc |
| PLAN | `PLAN.md` §9 | Repo | |

Geprüft wurden außerdem drei Sessions ohne Bezug zu ClaudeKitchen (supervisor-agent, Festplatten-Reinigung): „1Password-Integration für Agenten“, „Aufbau-Fortschritt“ und „Chats kompilieren und Memory/Status“.
