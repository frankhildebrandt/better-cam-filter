---
layout: ../../layouts/DocsLayout.astro
title: "Tests & Diagnose"
description: "Build-Prüfung, Swift-Tests, Maskendiagnose und manuelle Installationstests."
generated: true
---

## Prüfen

```sh
# Kompiliert App, eingebettete Extension und Codex-XPC-Dienst ohne Apple-Signierung:
xcodebuild -project BetterCam.xcodeproj -scheme BetterCam \
  -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO build

# Tests für Bildverarbeitung, Profile, Mediathek, Codex-JSON-RPC und Prozesslebenszyklus:
swift test

# Vergleich aus einem lokalen Kamerabild (optional: Screenshot-Crop in Pixeln ab links oben):
swiftc -O -swift-version 6 Shared/*.swift Shared/Segmentation/*.swift Tools/InspectMask.swift -o /tmp/inspect-mask
/tmp/inspect-mask /path/to/camera.png build/mask-evaluation
# /tmp/inspect-mask /path/to/window.png build/mask-evaluation 336 136 681 383

# Optionaler echter Netzwerk-/Modelltest (lädt beide Katalogmodelle, etwa 181 MB):
swiftc -O -swift-version 6 Shared/*.swift Shared/Segmentation/*.swift Tools/VerifyModelCatalog.swift -o /tmp/verify-model-catalog
/tmp/verify-model-catalog build/catalog-verification --all
```

Das Diagnosewerkzeug erzeugt `before.png`, `after.png` und `mask.png` lokal und
schaltet keine Kamera ein. Eigene Kamerabilder gehören nicht ins Git-Repository;
der Ausgabeordner `build/` ist ignoriert. Die Tests decken unter anderem Stuhl,
Arm, farbiges Kabel, kurze Verbinder, unveränderte weiche Personenränder und
abgelehnte dunkle Hintergrundflächen ab. Zeitliche Regressionstests prüfen positive
Erkennung bei Farbdrift, kurze Erkennungslücken, bestätigte Entfernung, bewegte
Mikrofonkanten und den Wechsel zwischen Personen- und Zubehörmaske.

Ein erfolgreicher Build und diese Tests ersetzen keinen Installationstest. Für den
End-to-End-Test auf einem Mac: signieren und installieren, BetterCam beispielsweise
in QuickTime auswählen, Quelle und Bildfilter prüfen, Stop/Start, USB-Abziehen und
App-Beenden testen. Kopfkontur, Mikrofon, Stuhl und Schutzbereiche bei Bewegung prüfen.
Beim Markieren muss der virtuelle Ausgang weiter gefiltert bleiben. Nach spätestens
500 ms ohne Producer muss Schwarz erscheinen;
die eigene virtuelle Kamera darf nicht als Eingangsquelle angeboten werden.

Das Xcode-Projekt und generierte Plists/Entitlements werden mitgeliefert; `project.yml`
ist die Quelle für Änderungen an Targets, Build-Einstellungen und Capabilities.
