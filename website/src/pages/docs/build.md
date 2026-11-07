---
layout: ../../layouts/DocsLayout.astro
title: "Download & Installation"
description: "BetterCam herunterladen, die virtuelle Kamera aktivieren oder die App selbst bauen."
generated: true
---

## Download und Installation

**[BetterCam 0.1.0 für macOS herunterladen](https://github.com/frankhildebrandt/better-cam-filter/releases/download/v0.1.0/BetterCam-v0.1.0-macos-universal.zip)** ·
[Release-Notizen](https://github.com/frankhildebrandt/better-cam-filter/releases/tag/v0.1.0) ·
[SHA-256-Prüfsumme](https://github.com/frankhildebrandt/better-cam-filter/releases/download/v0.1.0/SHA256SUMS.txt)

Für **macOS 14 oder neuer**, als Universal-App für Apple Silicon und Intel.
App, Kameraerweiterung und Hilfsdienst sind mit Developer ID signiert und von Apple
notarisiert. Für die Nutzung des fertigen Pakets sind kein Xcode und kein eigenes
Apple-Developer-Konto erforderlich. Der Download ist über das öffentliche GitHub-Release verfügbar.

1. ZIP entpacken und **BetterCam.app nach /Applications (Programme)** kopieren.
2. App dort öffnen. Unter **Einstellungen → Ausgabe → Virtuelle Kamera aktivieren**
   die Erweiterung installieren und in den macOS-Systemeinstellungen erlauben.
   Je nach macOS-Version unter **Allgemein → Anmeldeobjekte & Erweiterungen →
   Kameraerweiterungen** oder **Datenschutz & Sicherheit**. macOS kann einen Neustart verlangen.
3. Unter **Einstellungen → Kamera** deine Quelle wählen, im Hauptfenster **Kamera starten**
   und den Kamerazugriff erlauben. In deiner Video-App **BetterCam** auswählen;
   bereits geöffnete Video-Apps gegebenenfalls neu starten.

Optional ZIP und `SHA256SUMS.txt` in denselben Ordner laden und dort prüfen:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

Persönliche Hintergrundbilder und Modellgewichte sind nicht im App-Paket enthalten.
Eigene Bilder lassen sich importieren, optionale Modelle direkt in den Einstellungen laden.
Die Vorschau funktioniert auch ohne aktivierte virtuelle Kamera.

## Voraussetzungen

Die folgenden Voraussetzungen gelten nur für den Selbstbau.

- macOS 14+, Xcode mit Swift 6 und Command Line Tools.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) zum Neuerzeugen des mitgelieferten Xcode-Projekts (`brew install xcodegen`).
- Für die Installation der virtuellen Kamera: ein Apple Developer Team mit passenden
  Signierungsprofilen für App Groups und System Extensions. Ein unsignierter Build
  kann die Extension nicht aktivieren.

## Bauen und starten

```sh
xcodegen generate
open BetterCam.xcodeproj
```

In Xcode für **alle Targets** dasselbe Development Team wählen. Alternativ eine
nicht eingecheckte `Config/Local.xcconfig` anlegen:

```ini
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

Um ein vorhandenes **Developer ID Application**-Zertifikat für alle Targets zu
verwenden, zusätzlich in derselben Datei eintragen:

```ini
CODE_SIGN_STYLE = Manual
CODE_SIGN_IDENTITY = Developer ID Application
CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO
BETTERCAM_APP_PROFILE = BetterCam Developer ID
BETTERCAM_CAMERA_PROFILE = BetterCam Camera Developer ID
```

Die lokale Konfiguration gilt für Debug und Release und bleibt beim Neuerzeugen
des Projekts erhalten. Die beiden Profilnamen müssen zu den lokal installierten
Developer-ID-Profilen passen. Für die App ist **System Extension** erforderlich; die Profile
müssen zu Team, Bundle IDs, Zertifikat und aktivierten Capabilities passen.
Das Zertifikat allein ersetzt diese Berechtigungen nicht. Mit
`xcodebuild -allowProvisioningUpdates` kann Xcode bei manueller Signierung bereits
vorhandene Profile aus dem angemeldeten Konto laden.
Developer-ID-Builds enthalten keine Debugger-Berechtigung (`get-task-allow`). Für
eine Debugger-Sitzung stattdessen ein Development-Zertifikat und Development-Profile
verwenden und die lokale Einstellung `CODE_SIGN_INJECT_BASE_ENTITLEMENTS` entfernen.

Die Bundle IDs sind `de.bettercam.app`, `de.bettercam.camera` und
`de.bettercam.CodexServer` (eingebetteter XPC-Dienst). Der XPC-Dienst benötigt kein
eigenes Provisioning-Profil. Falls die App- oder Kamera-ID im
Developer Account nicht verfügbar sind, in `project.yml` ändern und die IDs in
`CameraConfiguration.swift`, `CameraDevice.authorizeProducer`, der App Group und
`CMIOExtensionMachServiceName` entsprechend angleichen. Die gemeinsame App Group
`$(TeamIdentifierPrefix)de.bettercam.camera` muss für beide Targets freigegeben sein.

### Developer-ID-Build für die virtuelle Kamera notarisieren

Eine gültige Developer-ID-Signatur allein reicht für die Systemerweiterung nicht.
Apple verlangt zusätzlich eine Notarisierung. Andernfalls kann die Aktivierung mit
**code signature invalid** scheitern, obwohl `codesign --verify` erfolgreich ist.
Die lokale Vorschau kann dabei weiterhin funktionieren.

Mit dem in Xcode angemeldeten Apple-Developer-Konto:

```sh
xcodebuild -project BetterCam.xcodeproj -scheme BetterCam -configuration Release \
  -archivePath build/notarization/BetterCam.xcarchive archive
xcodebuild -exportArchive -archivePath build/notarization/BetterCam.xcarchive \
  -exportOptionsPlist Config/DeveloperID-Export.plist \
  -exportPath build/notarization/upload -allowProvisioningUpdates
# Nach erfolgreicher Notarisierung:
xcodebuild -exportNotarizedApp -archivePath build/notarization/BetterCam.xcarchive \
  -exportPath build/notarization/release
codesign --verify --deep --strict build/notarization/release/BetterCam.app
codesign --verify --strict build/notarization/release/BetterCam.app/Contents/Library/SystemExtensions/de.bettercam.camera.systemextension
xcrun stapler validate build/notarization/release/BetterCam.app
spctl --assess --type execute --verbose=4 build/notarization/release/BetterCam.app
```

`Config/DeveloperID-Export.plist` verwendet die oben beschriebenen manuellen
Profilnamen und lädt ausschließlich zu Apples Notarisierungsdienst hoch. Es ist
keine Veröffentlichung im App Store. Bei anderen Profilnamen die Zuordnung anpassen.
Erst den erfolgreich notarisierten Export nach `/Applications` kopieren. Für eine
Aktivierungsfreigabe müssen Signaturprüfung, Ticketprüfung und Gatekeeper-Prüfung
erfolgreich sein; `spctl` sollte **Notarized Developer ID** ausgeben. Nach Änderungen
am signierten Programm muss der neue Build erneut notarisiert werden.

Grundlage: [Apple: System Extensions and DriverKit](https://developer.apple.com/videos/play/wwdc2019/702/?time=144),
[Apple: macOS-App zur Notarisierung hochladen](https://help.apple.com/xcode/mac/current/en.lproj/dev88332a81e.html).

1. Schema **BetterCam**, Ziel **My Mac**, bauen.
2. `BetterCam.app` aus dem Build-Verzeichnis nach **/Applications** kopieren.
3. App von dort öffnen und unter **Einstellungen → Ausgabe** auf **Virtuelle Kamera aktivieren** klicken.
4. Die Kameraerweiterung in den Systemeinstellungen erlauben. Je nach macOS-Version
   unter **Allgemein → Anmeldeobjekte & Erweiterungen → Kameraerweiterungen** oder
   **Datenschutz & Sicherheit**. macOS kann einen Neustart verlangen.
5. Unter **Einstellungen → Kamera** die Quelle auswählen, im Hauptfenster **Kamera starten** und den Kamerazugriff erlauben.
6. In der Video-App **BetterCam** als Kamera wählen. Bereits geöffnete Video-Apps
   gegebenenfalls neu starten, damit sie das neue Gerät entdecken.

**Importieren …** speichert einen Hintergrund in der Mediathek und aktiviert den Filter. Der Schalter
stellt auf das unveränderte Kamerabild zurück. Kamera stoppen gibt die Hardware frei;
die installierte virtuelle Kamera bleibt verfügbar und liefert Schwarz. Zum Wechseln
der Quelle erst stoppen. Die Bilddatei bleibt in der Mediathek gespeichert; der aktive Hintergrund wird pro Sitzung gesetzt.
