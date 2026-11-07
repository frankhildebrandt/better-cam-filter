---
layout: ../../layouts/DocsLayout.astro
title: "Überblick"
description: "BetterCam herunterladen, einrichten und verstehen. Hier beginnt dein Weg zur eigenen virtuellen Kamera."
---

BetterCam ist eine native macOS-Webcam-App in SwiftUI. Du wählst eine Kamera, ersetzt auf Wunsch den Hintergrund und gibst das verarbeitete Bild über die virtuelle Kamera **BetterCam** an eine Video-App weiter. Die erste veröffentlichte Version ist **0.1.0**.

**[BetterCam 0.1.0 herunterladen](https://github.com/frankhildebrandt/better-cam-filter/releases/download/v0.1.0/BetterCam-v0.1.0-macos-universal.zip)** · [Release-Notizen](https://github.com/frankhildebrandt/better-cam-filter/releases/tag/v0.1.0) · [Prüfsumme](https://github.com/frankhildebrandt/better-cam-filter/releases/download/v0.1.0/SHA256SUMS.txt)

Signierte und notarisierte Universal-App für macOS 14+, Apple Silicon und Intel. [Screenshots der aktuellen App](./screenshots/).

## In drei Schritten zum Kamerabild

1. **Herunterladen und installieren.** ZIP entpacken und die App nach `/Applications` kopieren. Das fertige Paket benötigt kein Xcode oder eigenes Developer-Konto. [Installation, Prüfsumme und optionaler Selbstbau](./build/).
2. **Kamera aktivieren.** Die App nach `/Applications` kopieren, unter **Einstellungen → Ausgabe** die virtuelle Kamera aktivieren und die Erweiterung in macOS erlauben. Unter **Einstellungen → Kamera** eine Quelle auswählen, im Hauptfenster **Kamera starten** und Kamerazugriff zulassen.
3. **Bild gestalten.** Über **Importieren …** einen Hintergrund in der Mediathek speichern und aktivieren. In deiner Video-App **BetterCam** als Kamera wählen. Bereits offene Video-Apps gegebenenfalls neu starten.

Die lokale Vorschau funktioniert auch ohne aktivierte virtuelle Kamera. Ein unsignierter Prüf-Build kann die Systemerweiterung nicht aktivieren.

## Was du konfigurieren kannst

- **[Kamera & Schutzbereiche](./camera/):** Person und Zubehör erhalten oder feste Bildbereiche mit dem Schutzpinsel markieren.
- **[Modelle & Masken](./models/):** Apple Vision ohne Modelldownload nutzen, U²-NetP/U²-Net herunterladen oder ein eigenes Core-ML-Modell importieren.
- **[Hintergründe & Codex](./backgrounds/):** Bilder auswählen, Profile anlegen und optional Hintergründe über Codex erzeugen.

## Lokal verarbeitet, optional erweitert

Die laufenden Kamerabilder werden lokal auf deinem Mac verarbeitet. Apple Vision ist standardmäßig verfügbar. Für optionale Modelle werden Modelldateien heruntergeladen; dafür werden keine Kamerabilder hochgeladen.

Die optionale Codex-Bildgenerierung überträgt deinen Prompt, Zusatzkontext und Profilbilder über Codex an OpenAI. Laufende Kamerabilder werden dafür nicht verwendet. Ein angemeldetes Codex-Konto mit Bildgenerierung ist erforderlich.

## Ausgabe und Grenzen

Unter **Einstellungen → Ausgabe** wählst du **HD, Full HD, QHD oder 4K** und **15, 24, 25, 30 oder 60 FPS**. Standard ist Full HD bei 30 FPS. Für Änderungen muss die Kamera gestoppt sein. Die tatsächliche Verarbeitungsbildrate hängt von Kamera, Mac und ausgewähltem Modell ab. Haare, schnelle Bewegungen und schlechtes Licht können sichtbare Maskenkanten verursachen. Schutzbereiche sind ortsfest und folgen keinen Objekten.

Audio und Videoaufzeichnung gehören nicht zum aktuellen Funktionsumfang. Das App-Paket enthält keine persönlichen Hintergrundbilder und keine zusätzlichen Modellgewichte.

## Für die Entwicklung

Die [Architektur](./architecture/) beschreibt den Weg vom Kameraframe zur Camera Extension. Unter [Tests & Diagnose](./testing/) findest du den unsignierten Build-Check, `swift test` und Werkzeuge zur Maskenprüfung. Der [Pages-Leitfaden](./pages/) erklärt diese Astro-Website und ihre Veröffentlichung.
