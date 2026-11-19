---
layout: ../../layouts/DocsLayout.astro
title: "Modell-Recherche"
description: "Recherche vom 19. November 2026: mögliche nächste Schritte für Segmentierung und Matting."
generated: true
---

## Recherche zu Segmentierung und Matting (19. November 2026)

Für Mikrofon, Arm und Kabel sind die Kontur im Einzelbild und die Wiedererkennung
bei Bewegung zwei verschiedene Anforderungen. Drei Kandidaten für einen Vergleich:

- **EdgeTAM** verfolgt per Punkt oder Box markierte Objekte in Videos. Damit ließe sich
  der Mikrofonaufbau einmal markieren. Der offizielle Core-ML-Export dokumentiert
  Bildencoder, Promptencoder und Maskendecoder. Für BetterCam braucht es zusätzlich die
  Videozustandsverwaltung und eine Laufzeitmessung mit der Kamera. [Meta, EdgeTAM](https://github.com/facebookresearch/EdgeTAM)
- **BiRefNet-V2** untersucht hochauflösende Einzelbildmasken für dünne Strukturen und
  offene Zwischenräume. Als Referenz für Kabelkanten ist es interessant. Die publizierten
  Bildbenchmarks messen weder zeitliches Flackern noch die Live-Bildrate auf diesem Mac.
  [Originalarbeit, November 2026](https://arxiv.org/abs/2611.11272)
- **Cutie** übernimmt eine Startmaske und verfolgt das bezeichnete Objekt mit einem
  Gedächtnis über die Folgeframes. Ein sorgfältig markierter Arm samt Kabel könnte so
  auch beim Schwenken sichtbar bleiben. Die Qualität am lokalen Setup und eine native
  Integration sind offen. [Forschungsprojekt und Referenzcode](https://github.com/hkchengrex/Cutie)

Diese drei Modelle sind Recherchekandidaten. In der App verfügbar sind die beiden
Vision-Verfahren, die beiden U²-Net-Downloads und kompatible eigene Core-ML-Modelle.

### Weitere Ansätze

- [Apples Foreground Instance Masks](https://developer.apple.com/videos/play/wwdc2023/10176/):
  native Segmentierung allgemeiner Vordergrundobjekte ab macOS 14. Diese Version
  ist als **Apple Vision · Vordergrundobjekte** wählbar. Der Standard verwendet
  die Personenmaske als Anker, weil wechselnde allgemeine Instanzen auch Raumobjekte
  freigeben können. Keine zusätzlichen Gewichte und keine Server erforderlich.
- [Robust Video Matting (RVM)](https://github.com/PeterL1n/RobustVideoMatting):
  zeitliches Gedächtnis und Core-ML-Unterstützung sind für flackerarme Personenmasken
  interessant. Es ist ausdrücklich für Human Matting trainiert; ein Erhalt von
  Mikrofon und Stuhl folgt daraus nicht. Der offizielle Code steht unter GPL-3.0.
- [SAM 3 / SAM 3.1](https://github.com/facebookresearch/sam3):
  segmentiert und verfolgt Objekte mit Text- und Bildprompts. Damit ist es ein Kandidat
  für explizit ausgewählte Personen, Mikrofone und Stühle. Metas Referenzimplementierung
  setzt Python/PyTorch und CUDA voraus; Kantengüte und Kameraleistung müssen vor einer
  Integration gemessen werden.
- [SAM 3 mit Apples Core AI](https://developer.apple.com/videos/play/wwdc2026/326/):
  Apple bietet inzwischen auch eine native Swift-Integration für textgesteuerte
  SAM-3-Bildsegmentierung. Sie benötigt macOS 27; auf diesem Mac läuft aktuell
  macOS 26.6.2. Damit ist sie ein sinnvoller späterer Integrationskandidat, aber kein
  direkt nutzbarer Ersatz in diesem Build. Ein vollständiger Video-Tracker und
  garantierte 1080p/30 werden durch die Bildsegmentierungs-API nicht zugesagt.
- [SAM 2](https://ai.meta.com/research/sam2/):
  Objektauswahl per Klick und zeitliche Verfolgung passen zum Anwendungsfall.
  Der [Hugging-Face-Core-ML-Port](https://github.com/huggingface/segment-anything-2)
  unterstützt laut README bislang nur Bildsegmentierung, keinen vollständigen
  Video-Tracker. Ein Image-Encoder allein ersetzt keine zeitliche Video-Pipeline.
- [Background Matting V2](https://github.com/PeterL1n/BackgroundMattingV2):
  nutzt zusätzlich ein aufgenommenes Referenzbild des leeren Hintergrunds. Als
  alternative Kalibrierung für eine feste Kamera interessant; Eignung für beliebige
  Gegenstände und Laufzeit auf Apple Silicon sind damit noch nicht belegt.

Empfehlung: Für die aktuelle native App Vision plus Schutzbereiche verwenden.
Für eine spätere automatische Verfolgung explizit gewählter Gegenstände SAM evaluieren;
für bessere Personenränder RVM separat bewerten. Die publizierten NVIDIA-FPS sind
keine Leistungszusage für diesen Mac. Keines dieser externen Modelle ist eingebaut.

Technische Grundlage: [Apples Camera-Extension-Anleitung](https://developer.apple.com/documentation/coremediaio/creating-a-camera-extension-with-core-media-i-o)
und [WWDC22: Create camera extensions with Core Media IO](https://developer.apple.com/videos/play/wwdc2022/10022/).
