---
layout: ../../layouts/DocsLayout.astro
title: "Hintergründe & Codex"
description: "Profile, Referenzbilder, Mediathek und die optionale Bildgenerierung."
generated: true
---

## Hintergründe mit Codex erzeugen

Voraussetzung ist eine aktuelle Codex CLI auf **demselben Mac** mit angemeldetem
Konto und verfügbarer Bildgenerierung. Einmalig im Terminal anmelden:

```sh
codex login
```

BetterCam startet den App Server beim Klick auf **Hintergrund erzeugen** automatisch
und beendet den eigenen Prozess nach Erfolg, Fehler, Abbruch oder beim Beenden der
App. Ein offenes Terminal oder ein vorab gestarteter Server ist nicht erforderlich.
Die App sucht Codex im `PATH`, in den üblichen Homebrew-Verzeichnissen, unter
`~/.npm-global/bin` und `~/.local/bin` sowie im installierten Codex-App-Bundle.

1. Unter **Einstellungen → Hintergründe** auf **Neues Profil …** klicken; der Generator verlinkt diesen Bereich über **Profile verwalten …**.
2. Einen Profilnamen und den **Pre-Prompt** mit den festen Vorgaben eintragen,
   beispielsweise Raumstil, Farben oder Markenregeln.
3. Optional über **Bilder hinzufügen …** Logos, Stilvorlagen und andere
   Referenzbilder importieren. BetterCam speichert eigene PNG-Kopien; die
   ursprünglichen Dateien müssen anschließend nicht mehr verfügbar sein.
4. **Profil speichern**, im Hauptfenster **Hintergrund erzeugen …** öffnen, das Profil auswählen und bei Bedarf im Feld
   **Zusätzlicher Kontext** die Wünsche für dieses einzelne Bild ergänzen.
5. **Hintergrund erzeugen** klicken. Das fertige Bild wird als Kamerahintergrund
   aktiviert. Die Kamera muss zum Generieren nicht laufen.

Pre-Prompt und **alle** Profilbilder werden bei jeder Generierung erneut
übergeben. Der Zusatzkontext kann leer bleiben. Profile können unter
**Einstellungen → Hintergründe** bearbeitet oder gelöscht werden.
Die Sidebar zeigt die acht neuesten Mediathek-Bilder als Miniaturen. Über **Alle Bilder …**
oder **Mediathek öffnen …** im Generator lassen sich alle importierten und erzeugten Bilder auswählen. Ein Klick aktiviert
das Bild als Kamerahintergrund; das aktive Bild ist markiert. Neue Bilder werden
automatisch dauerhaft gespeichert, die neuesten stehen zuerst. Sie bleiben auch
nach einem App-Neustart und nach dem Löschen des zugehörigen Profils verfügbar.
Ein bereits vorhandenes `last-background.png` wird einmalig in die Mediathek übernommen.

Profile, importierte Bilder und die Mediathek liegen im
Application-Support-Verzeichnis der App unter `BetterCam/Backgrounds`.
Das ausgewählte Profil und die Codex-Verbindungseinstellungen bleiben nach einem Neustart erhalten;
der aktive Kamerahintergrund wird weiterhin pro Sitzung gesetzt.

Unter **Einstellungen → Hintergründe → Verbindung** ist **Codex automatisch bei Bedarf starten** standardmäßig
aktiviert. Ein eingebetteter, separat signierter XPC-Dienst startet
`codex app-server --listen stdio://` und transportiert dessen JSON-RPC-Nachrichten
über Pipes. Der Hilfsdienst läuft außerhalb der App-Sandbox, damit Codex auf seine
bestehende Anmeldung und Konfiguration zugreifen kann. BetterCam selbst und die
Kameraerweiterung behalten ihre macOS-Sandbox; die Kameraerweiterung erhält keinen
Netzwerkzugriff. Es wird kein API-Key in BetterCam gespeichert.

Wer einen eigenen App Server verwenden möchte, deaktiviert den automatischen Start
und trägt eine lokale WebSocket-Adresse ein, beispielsweise `ws://127.0.0.1:4500`.
Diesen Server mit `codex app-server --listen ws://127.0.0.1:4500` selbst starten.
Die App akzeptiert ausschließlich Loopback-Adressen und beendet extern gestartete
Server nicht.
Für jede Generierung wird ein eigener temporärer Thread mit `workspace-write` und
`approvalPolicy: never` angelegt. Interaktive Freigabeanfragen werden abgelehnt.
**Abbrechen** unterbricht den laufenden Turn. Bei Fehlern bleibt das bisherige
Kamerahintergrundbild aktiv.

Zur Bildgenerierung werden Pre-Prompt, Zusatzkontext und Profilbilder über Codex
an OpenAI übertragen. Die laufenden Kamerabilder werden dafür nicht verwendet.
Bildgenerierung muss vom verwendeten Codex-Konto unterstützt werden; BetterCam
zeigt Fehler des Servers an. Der optionale WebSocket-Transport des App Servers ist
experimentell. Protokollgrundlage: [offizielle OpenAI-Dokumentation zum Codex App Server](https://learn.chatgpt.com/docs/app-server).
