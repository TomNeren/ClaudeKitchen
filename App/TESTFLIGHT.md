# TestFlight einrichten

Builds für TestFlight entstehen auf deinem Mac mit `Scripts/testflight.sh`, nicht in GitHub. Das Skript baut `origin/main` in einem eigenen Arbeitsbaum, signiert über das in Xcode angemeldete Konto des Schulteams und lädt per `asc` hoch. In GitHub liegen dafür keine Schlüssel, und es gibt keinen Runner. Das Repo ist öffentlich, ein Runner auf dem Mac könnte über Pull Requests aus Forks fremden Code ausführen.

## Einmalig

1. **Xcode-Konto:** Auf dem Mac in Xcode > Einstellungen > Accounts mit der Apple-ID des Schulteams anmelden. Ohne Konto scheitert das Signieren.
2. **Team-ID:** `App/Config/Local.xcconfig.example` nach `App/Config/Local.xcconfig` kopieren und die Team-ID des Schulteams eintragen. Die Datei ist von Git ausgenommen.
3. **Bundle-IDs:** Unter developer.apple.com > Identifiers `com.tomren.claudekitchen` und `com.tomren.claudekitchen.widgets` anlegen. Xcode kann das beim ersten Archiv auch selbst, wenn das Konto die Rechte hat.
4. **App-Eintrag:** In App Store Connect unter Apps > + > Neue App anlegen, Plattform iOS, Name „Omni Cook“, Bundle-ID `com.tomren.claudekitchen`. Die Bundle-ID lässt sich danach nicht mehr ändern.
5. **asc:** Der vorhandene Team-Key (Profil `lehrerapp`, Rolle App-Manager) reicht für Upload und Testgruppen. Prüfen mit `asc apps list --bundle-id com.tomren.claudekitchen`. Ein eigenes Profil ist möglich, aber nicht nötig; dann `ASC_PROFILE` setzen.
6. **Testgruppe:** Unter der App > TestFlight > Interne Tests eine Gruppe anlegen, etwa „Ich“, und dich eintragen. Auf dem iPhone die TestFlight-App installieren.

## Hochladen

```zsh
Scripts/testflight.sh                         # Probelauf: nur bauen und exportieren
Scripts/testflight.sh --upload                # hochladen, keiner Gruppe zuweisen
Scripts/testflight.sh --upload --group "Ich"  # hochladen und der Gruppe zuweisen
```

- Gebaut wird außerhalb des Repos, unter `/Volumes/Work/Developer-Daten/<Benutzer>/sitzungs-builds/claudekitchen-testflight`. Dort liegen auch die Logs. Mit `CLAUDEKITCHEN_BUILD_ROOT` lässt sich der Ort ändern.
- Die Version kommt aus `MARKETING_VERSION` in `App/project.yml`. Die Build-Nummer ist die Zahl der Commits auf dem Stand (`git rev-list --count HEAD`) und steigt mit jedem Merge.
- Die Testnotizen in TestFlight („Was testen“) füllt das Skript mit den Commit-Titeln seit dem letzten Upload.
- Nach dem Upload prüft Apple den Build 5 bis 30 Minuten, das Skript wartet darauf.
- Exportfragen entfallen: Die App nutzt nur HTTPS über das System (`ITSAppUsesNonExemptEncryption = NO`).
- Eine interne Gruppe mit automatischer Verteilung bekommt jeden Build sofort. Weil die App kein CloudKit nutzt, ist das unkritisch.

## Wenn es scheitert

- **„No Accounts“ oder „No signing certificate“:** In Xcode ist kein Konto angemeldet, siehe Schritt 1.
- **„Cloud signing permission error“:** Ein App-Manager-Key wurde an `xcodebuild` gegeben. Das Skript tut das nicht. Signiert wird nur über das Xcode-Konto.
- **„No profiles for …widgets“:** Bundle-ID der Widgets anlegen (Schritt 3).
- **App nicht gefunden:** App-Eintrag fehlt (Schritt 4) oder das asc-Profil gehört zu einem anderen Team.
- **Build-Nummer schon vergeben:** Kommt nur vor, wenn derselbe Stand zweimal hochgeladen wird. Erst nach einem neuen Merge erneut hochladen.

## Schlüssel widerrufen

Bei Verdacht auf ein Leck: den Schlüssel in App Store Connect widerrufen, einen neuen anlegen und `asc auth login` neu ausführen. Ein Teamschlüssel gilt für alle Apps des Teams, also auch für die LehrerApp.
