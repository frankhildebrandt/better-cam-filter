# Automatische macOS-Releases

`.github/workflows/release.yml` startet beim **Veröffentlichen eines GitHub-Releases**
(auch Prereleases) und lässt sich unter Actions → **Release macOS** für einen
vorhandenen Release-Tag erneut starten. Tags heißen `vX.Y.Z`, optional etwa
`v0.8.0-beta.1`. Der Tag muss den Workflow und `Tools/ci` enthalten.

Der Workflow testet, baut ein Universal-Archiv für Apple Silicon und Intel,
signiert App, Kameraerweiterung und XPC-Dienst, lädt das signierte ZIP zu Apple
und wartet auf **Accepted**. Danach heftet er das Ticket an und prüft Ticket,
Signaturen, Gatekeeper und die Notarisierung der Kameraerweiterung ausdrücklich.
Erst dann werden `BetterCam-<tag>-macos-universal.zip` und `SHA256SUMS.txt` am
bestehenden Release angehängt. Der Build veröffentlicht keine neuen Releases.

Die Marketing-Version kommt vom Tag (ohne Prerelease-Suffix), die Buildnummer ist
`CURRENT_PROJECT_VERSION` aus `project.yml` plus GitHub-Runnummer. Dadurch liegt
der erste CI-Build über dem lokalen Build und folgende Releases steigen weiter.
Neue Release-Tags sollen den Projekt-Buildzähler nicht zurücksetzen.

Der Runner ist `macos-15` mit Xcode 26.2. Actions sind auf Commits gepinnt;
Build und Tests haben nur Lesezugriff, nur der separate Veröffentlichungsjob hat
`contents: write`. Der signierende Job läuft weder bei Pull Requests noch bei
normalen Pushes. `.github/workflows/ci.yml` prüft diese ohne Signing-Secrets.

## Einmalig erforderliche Zugangsdaten

Repository → Settings → Secrets and variables → Actions:

| Name | Inhalt |
|---|---|
| Variable `APPLE_TEAM_ID` | `4R24354Z88` für das aktuelle Team |
| Secret `DEVELOPER_ID_P12_BASE64` | Base64 der **Developer ID Application**-Identität inklusive privatem Schlüssel |
| Secret `DEVELOPER_ID_P12_PASSWORD` | Passwort des P12-Exports |
| Secret `APP_PROFILE_BASE64` | Base64 des Developer-ID-Profils für `de.bettercam.app` |
| Secret `CAMERA_PROFILE_BASE64` | Base64 des Developer-ID-Profils für `de.bettercam.camera` |
| Secret `NOTARY_KEY_BASE64` | Base64 des privaten App-Store-Connect-Team-API-Schlüssels `.p8` |
| Secret `NOTARY_KEY_ID` | Key ID dieses API-Schlüssels |
| Secret `NOTARY_ISSUER_ID` | Issuer ID des Teams |

Das Zertifikat lässt sich in der Schlüsselbundverwaltung unter **Meine Zertifikate**
als passwortgeschützte `.p12` exportieren. Genau die Developer-ID-Identität des
Teams auswählen, nicht sämtliche Schlüssel exportieren. Die beiden Profile sind
auch in einer funktionierenden installierten App vorhanden:

```
/Applications/BetterCam.app/Contents/embedded.provisionprofile
/Applications/BetterCam.app/Contents/Library/SystemExtensions/de.bettercam.camera.systemextension/Contents/embedded.provisionprofile
```

Für die Notarisierung einen dedizierten **Team-API-Key** mit Developer-Rolle oder
passender höherer Rolle in App Store Connect verwenden. Die lokale Xcode-Anmeldung
wird nicht an GitHub übertragen. Der private Schlüssel wird von Apple nur einmal
zum Download angeboten. P12, Passwort und API-Key ermöglichen dem Release-Runner
das Signieren/Notarisieren; nur vertrauenswürdige Personen dürfen Release-Tags und
Workflows ändern. Optional können Secrets in ein GitHub-Environment mit passenden
Freigaberegeln verschoben werden; dann im Buildjob dessen `environment` ergänzen.

Mit vorhandenen, bewusst für GitHub bereitgestellten Dateien erledigt dieses
Setupwerkzeug die verschlüsselte Ablage. Es überträgt die genannten Dateien an
das angegebene GitHub-Repository, liest keine anderen Schlüssel aus und fragt
das P12-Passwort verdeckt ab:

```sh
python3 Tools/ci/configure_secrets.py \
  --repo frankhildebrandt/better-cam-filter --team-id 4R24354Z88 \
  --certificate /sicher/DeveloperID.p12 \
  --app-profile /Applications/BetterCam.app/Contents/embedded.provisionprofile \
  --camera-profile /Applications/BetterCam.app/Contents/Library/SystemExtensions/de.bettercam.camera.systemextension/Contents/embedded.provisionprofile \
  --notary-key /sicher/AuthKey_KEYID.p8 \
  --notary-key-id KEYID --notary-issuer-id ISSUER-UUID
```

Keine dieser Dateien ins Repository einchecken. Der Workflow legt Schlüssel und
Profile nur auf dem temporären GitHub-Runner ab und entfernt sie auch nach einem
Fehler. In Artefakten liegen nur das geprüfte App-ZIP und dessen Prüfsumme.

## Release erstellen und prüfen

1. Änderungen inklusive Workflow nach `main` übernehmen; CI muss erfolgreich sein.
2. Einen neuen Tag auf dem gewünschten Commit anlegen und ein GitHub-Release
   veröffentlichen. Auch der Tag sollte auf einem geprüften Commit liegen.
3. Actions → Release macOS beobachten. Bei fehlenden/abgelaufenen Secrets oder
   abgelehnter Notarisierung werden keine App-Dateien veröffentlicht.
4. ZIP vom Release herunterladen, App nach `/Applications` kopieren und die
   virtuelle Kamera aktivieren. Die übliche macOS-Freigabe bleibt erforderlich.

Dieser Ablauf hängt Assets **nach** Veröffentlichung an: GitHubs optionale
Release-Immutability darf dafür nicht aktiv sein. Für unveränderliche Releases
zuerst ein Draft-Release mit Tag anlegen, den Workflow manuell für diesen Tag
laufen lassen und erst nach den angehängten Assets veröffentlichen. Ist beim
Veröffentlichen bereits das erwartete App-ZIP samt `SHA256SUMS.txt` angehängt, überspringt
der automatische Workflow den erneuten Build. Ein manueller Start baut weiterhin erneut. Bestehende Assetnamen werden
bei einem manuellen Wiederholungslauf ersetzt (`--clobber`).

Notarisierung kann bei Apple länger dauern. Ein Timeout ist keine Freigabe; die
Submission-ID in `build/release/notarization.json` beziehungsweise im Run-Log
zur Diagnose verwenden. Ein abgebrochener Run kann bei Apple bereits eingereicht
sein. Nach einer Ablehnung zuerst deren Ursache beheben, statt ungeprüfte ZIPs
manuell zu veröffentlichen.

Grundlagen: [GitHub Release-Events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#release),
[Apple Notary-Workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Lokal vorbereitetes erstes Release (0.1.0)

0.1.0 wurde lokal mit den vorhandenen Developer-ID-Profilen archiviert und über
Xcodes angemeldetes Developer-Konto notarisiert. Der Export wurde einschließlich
Kameraerweiterung mit `codesign`, `stapler` und Gatekeeper geprüft und als Universal-ZIP
zusammen mit `SHA256SUMS.txt` an ein Draft-Release angehängt. Erst anschließend wurde
das Release veröffentlicht. Persönliche Hintergründe und Modelldownloads gehören
nicht ins Release-Paket.

Dieser Weg ersetzt nicht die noch nötigen CI-Zugangsdaten: Für künftige automatische
Builds müssen P12-Identität samt Passwort und Notary-Team-API-Key in GitHub hinterlegt
sein. Die beiden Provisioning-Profile und die Team-ID allein reichen nicht.
