# TestFlight einrichten

Der Workflow `.github/workflows/testflight.yml` baut jeden Stand von `main`, signiert ihn und lädt ihn nach TestFlight. Pull Requests lösen ihn nie aus. Fehlen die Zugangsdaten, überspringt er den Upload, statt rot zu werden. Von Hand startest du ihn unter Actions > TestFlight > Run workflow.

## Einmalig in App Store Connect

1. **App anlegen:** Apps > + > Neue App. Plattform iOS, Name zum Beispiel „Omni Cook“, Bundle-ID `de.tomneren.ClaudeKitchen`. Fehlt die Bundle-ID in der Auswahl, lege sie unter developer.apple.com > Identifiers an (dort auch `de.tomneren.ClaudeKitchen.Widgets`).
2. **API-Schlüssel:** Benutzer und Zugriff > Integrationen > App Store Connect API > Teamschlüssel > +. Zugriff: **Admin**. Apple nennt für Zertifikate und Profile, die in der Cloud verwaltet werden, nur Admin; schwächere Rollen scheitern an der Signatur. Lade die `.p8`-Datei herunter (geht nur einmal) und notiere Schlüssel-ID und Issuer-ID.
3. **TestFlight:** Unter der App > TestFlight > Interne Tests eine Gruppe anlegen und dich eintragen. Auf dem iPhone die TestFlight-App installieren.

## Einmalig in GitHub

1. Settings > Environments > New environment, Name `testflight`.
2. Unter „Deployment branches and tags“ **Selected branches** wählen und nur `main` erlauben. So kommt kein anderer Zweig an die Daten.
3. Im selben Environment vier Secrets anlegen:

| Secret | Inhalt |
| --- | --- |
| `ASC_KEY_ID` | Schlüssel-ID, zehn Zeichen |
| `ASC_ISSUER_ID` | Issuer-ID (UUID) |
| `ASC_PRIVATE_KEY` | Der ganze Inhalt der `.p8`-Datei, mit den Zeilen `BEGIN` und `END` |
| `APPLE_TEAM_ID` | Team-ID aus developer.apple.com > Membership |

Nichts davon gehört ins Repo, auch nicht in `Local.xcconfig`. Die `.p8`-Datei danach sicher ablegen (etwa im Passwortmanager) und vom Schreibtisch löschen.

## Ablauf und Build-Nummern

- Die Version kommt aus `MARKETING_VERSION` in `App/project.yml`. Die Build-Nummer ist `Lauf.Versuch` des Workflows, etwa `42.1`, und steigt immer.
- Nach dem Upload prüft Apple den Build 5 bis 30 Minuten, dann bietet TestFlight ihn an.
- Exportfragen entfallen: Die App nutzt nur HTTPS über das System (`ITSAppUsesNonExemptEncryption = NO`).

## Wenn es scheitert

- **403 „no access to cloud-managed distribution certificates“:** Unter Benutzer und Zugriff prüfen, ob der Zugriff auf Cloud-verwaltete Verteilungszertifikate erlaubt ist; sonst einmal in Xcode mit dem Admin-Konto ein Archiv hochladen, damit das Zertifikat entsteht.
- **„No profiles for …Widgets“:** Bundle-ID der Widgets unter Identifiers anlegen.
- **Build-Nummer schon vergeben:** Workflow neu starten; der Versuchszähler erhöht die Nummer.

## Schlüssel widerrufen

Bei Verdacht auf ein Leck: den Schlüssel in App Store Connect widerrufen, einen neuen anlegen und die Secrets ersetzen. Ein Teamschlüssel gilt für alle Apps des Teams, deshalb lieber einmal zu oft widerrufen.
