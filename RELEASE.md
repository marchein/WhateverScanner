# Release-Leitfaden: TestFlight & App Store

Diese Checkliste beschreibt, wie WhateverScanner als Build an TestFlight-Tester
verteilt und später im App Store veröffentlicht wird.

## 1. Einmalige Vorbereitung

### Apple Developer / App Store Connect
- [ ] Aktive Mitgliedschaft im Apple Developer Program (Team `UJR28ZV94C`, siehe `project.yml`).
- [ ] Bundle-ID `de.marc-hein.whateverscanner` unter *Certificates, Identifiers & Profiles* registriert
      (passiert bei automatischer Signierung beim ersten Archivieren automatisch).
- [ ] In App Store Connect eine neue App anlegen:
  - Plattform: iOS, Primärsprache: Deutsch (oder Englisch)
  - Bundle-ID: `de.marc-hein.whateverscanner`
  - SKU: frei wählbar, z. B. `whateverscanner`
- [ ] **Datenschutzerklärung** öffentlich erreichbar hosten (Pflicht für jede App).
      Eine Vorlage liegt in [PRIVACY.md](PRIVACY.md) – z. B. über GitHub Pages veröffentlichen
      und die URL in App Store Connect unter *App-Informationen → Datenschutzrichtlinien-URL* eintragen.
- [ ] **App-Datenschutz** („Nutzungsangaben“) in App Store Connect ausfüllen:
      *„Wir erfassen keine Daten von dieser App“* – die App hat kein Tracking, keine Analytics,
      keinen eigenen Server. Dokumente gehen nur an die Ziele, die der Nutzer selbst konfiguriert.
      Das deckt sich mit dem mitgelieferten Privacy Manifest (`WhateverScanner/PrivacyInfo.xcprivacy`).
- [ ] **Exportkonformität**: `ITSAppUsesNonExemptEncryption = NO` ist in der `Info.plist` gesetzt.
      Die App nutzt nur Standard-Verschlüsselung des Betriebssystems bzw. von Standardprotokollen
      (HTTPS, SMB-Signierung/-Verschlüsselung), daher entfällt die Frage bei jedem Upload.

### Xcode Cloud (empfohlen)
1. Xcode 26 oder neuer lokal öffnen (das App-Icon liegt im Icon-Composer-Format `AppIcon.icon`,
   das erst ab Xcode 26 unterstützt wird; Apple verlangt für Uploads ohnehin ein aktuelles SDK).
2. Lokal `xcodegen generate` ausführen und `WhateverScanner.xcodeproj` öffnen.
3. *Product → Xcode Cloud → Create Workflow…*:
   - Produkt: `WhateverScanner`, Scheme: `WhateverScanner` (wird von XcodeGen als **shared** Scheme erzeugt).
   - Start Condition: z. B. Branch `main` oder Tag `v*`.
   - Actions: **Test** (iOS-Simulator) und **Archive** (Plattform iOS, Deployment Preparation:
     *TestFlight (Internal Testing Only)* bzw. *TestFlight and App Store*).
   - Post-Action: *TestFlight Internal Testing* → Gruppe auswählen.
4. Das Skript [`ci_scripts/ci_post_clone.sh`](ci_scripts/ci_post_clone.sh) erzeugt das Projekt in
   Xcode Cloud automatisch und legt `Package.resolved` an.
5. **Build-Nummern** vergibt Xcode Cloud beim Archivieren automatisch fortlaufend – sie müssen nicht
   manuell hochgezählt werden.

## 2. Einen TestFlight-Build veröffentlichen

1. Versionsnummer prüfen/erhöhen in `project.yml`:
   ```yaml
   MARKETING_VERSION: "1.0"        # sichtbare Version (1.0, 1.1, 2.0 …)
   CURRENT_PROJECT_VERSION: "1"    # Build-Nummer (nur für manuelle Archive relevant)
   ```
2. Änderungen pushen → Xcode Cloud baut, testet, archiviert und lädt zu TestFlight hoch.
   *Ohne Xcode Cloud:* `xcodegen generate`, in Xcode *Any iOS Device (arm64)* wählen,
   *Product → Archive* → *Distribute App → App Store Connect*. Dabei die Build-Nummer
   (`CURRENT_PROJECT_VERSION`) bei jedem Upload erhöhen.
3. In App Store Connect unter *TestFlight*:
   - **Interne Tester** (bis zu 100 Personen aus deinem App-Store-Connect-Team) bekommen den Build sofort.
   - **Externe Tester** (bis zu 10.000, per E-Mail oder öffentlichem Link): Gruppe anlegen,
     Build hinzufügen, *„Was soll getestet werden?“* ausfüllen. Der erste Build pro Version
     durchläuft eine kurze **Beta-App-Review**.
4. Tester installieren die App über die TestFlight-App. Die Version inkl. Build-Nummer steht
   in der App unter *Einstellungen → Über → Version* – bitte bei Feedback angeben.
5. Crash-Reports und Feedback (Screenshot-Feedback aus TestFlight) erscheinen in
   Xcode → *Window → Organizer* bzw. in App Store Connect unter *TestFlight → Feedback*.
   Diagnose-Logs schreibt die App ins Unified Logging (Subsystem `de.marc-hein.whateverscanner`,
   Kategorien `scan`, `export`, `settings`) – sichtbar in der Console.app bei angeschlossenem Gerät.

## 3. Hinweise für Beta-App-Review & App Review

Die App kann **ohne eigenen Server** vollständig genutzt werden: Im Onboarding gibt es
*„Später einrichten“* – Scans werden dann in der Dateien-App unter
*Auf meinem iPhone → WhateverScanner* gespeichert. Für die Notizen an das Review-Team
(*App Review Information → Notes*) eignet sich z. B.:

> WhateverScanner scans paper documents with the camera and saves them as PDF.
> No account or server is required: on the setup screen tap "Skip for Now" – scans are
> then saved to the Files app (On My iPhone › WhateverScanner). Uploading to WebDAV/SMB
> servers is optional and only goes to servers the user configures themselves.
> The app needs a device with a camera; document scanning is not available in the Simulator.

Optional kannst du einen öffentlich erreichbaren Test-WebDAV-Zugang angeben, damit
das Review auch den Upload ausprobieren kann.

## 4. App-Store-Veröffentlichung

Zusätzlich zu TestFlight benötigt die App-Store-Einreichung:

- [ ] **Screenshots**: iPhone 6,9" (z. B. iPhone 16/17 Pro Max) und – da die App auch auf dem iPad
      läuft (`TARGETED_DEVICE_FAMILY = 1,2`) – iPad 13". Wenn das iPad nicht unterstützt werden
      soll, in `project.yml` `TARGETED_DEVICE_FAMILY: "1"` setzen.
- [ ] Beschreibung, Untertitel, Keywords, Support-URL (z. B. GitHub-Issues-Seite), Kategorie
      *Dienstprogramme* (bereits als `LSApplicationCategoryType` gesetzt), Altersfreigabe-Fragebogen.
- [ ] Preis/Verfügbarkeit festlegen.
- [ ] Build auswählen → *Zur Prüfung einreichen*.

### Bekannte Punkte, die du vor der Einreichung noch prüfen solltest
- **App-Icon**: Das Icon basiert auf dem SF Symbol `document.viewfinder.fill`. Laut SF-Symbols-Lizenz
  dürfen SF Symbols **nicht in App-Icons** verwendet werden. Für den App Store sollte das Icon
  durch eine eigene Grafik ersetzt werden (Icon Composer: `WhateverScanner/AppIcon.icon`).
- **App-Name**: Prüfe vorab in App Store Connect, ob der Name „WhateverScanner“ noch frei ist.
- **HTTP-Server**: Unverschlüsselte `http://`-WebDAV-Server funktionieren nur im lokalen Netz
  (`.local`-Namen, Hostnamen ohne Domain). Für Server im Internet ist `https://` Pflicht
  (App Transport Security). Das ist bewusst so, da ein globales Abschalten von ATS bei der
  App Review begründet werden müsste.
