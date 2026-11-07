---
layout: ../../layouts/DocsLayout.astro
title: "Architektur"
description: "Capture, lokale Bildverarbeitung und die CoreMediaIO Camera Extension."
generated: true
---

## Architektur

```text
AVCaptureDevice → AVCaptureVideoDataOutput
  → FrameProcessor (Core Image, Vision-Vordergrundmaske + Schutzbereiche)
  ├─ verarbeitete SwiftUI-Vorschau (bis zu 15 FPS)
  └─ CoreMediaIO Sink-Queue → Camera Extension → Source-Stream
                                              → Video-Apps / Browser
```

- **App/Camera:** Capture und Verarbeitung auf einer seriellen Queue, veraltete
  Eingangsframes werden verworfen. Ausgabe in konfigurierbarem BGRA-Format bis 4K und 60 FPS,
  mit IOSurface-Puffern und begrenztem Pool. Die Extension wird bei Bedarf alle
  zwei Sekunden erneut gesucht, sodass die Vorschau auch ohne Installation läuft.
- **CameraExtension:** stabiles Geräte-/Stream-UUID-Paar und Source-/Sink-Streams.
  Ein Producer gleichzeitig, auf die App-Signatur-ID beschränkt. Die Extension
  konsumiert auch ohne Zuschauer und sendet an alle Kamera-Clients. Ohne aktuelle
  Frames spätestens nach 500 ms Schwarz; beim regulären Stop wird das letzte Bild
  sofort verworfen. Die Kamera gibt keine eigenen Hardware-Captures in Auftrag.
- **Shared:** Ausgabeformat, Seitenverhältnis, Vision-Segmentierung, Schutzmaske,
  Masken-Compositing und Sample-Puffer. Masken werden in normalisierten Koordinaten
  auf das bereits zugeschnittene Kamerabild abgebildet, ohne erneuten Aspect-Fill-Crop.
  `AccessoryMaskRefiner` analysiert Bild und Maske bei 512 Pixeln Breite.
  `AccessoryRegions` ergänzt begrenzt verbundene Komponenten. `AccessoryTemporalFilter`
  bestätigt nur zusätzliche Zubehörpixel; die aktuelle hochauflösende Personenmaske
  und explizite Schutzbereiche bleiben davon unabhängig.
  Weitere Filter werden vor dem Rendern in `FrameProcessor` ergänzt und gelten
  damit gleichzeitig für Vorschau und virtuelle Kamera.

1080p/30 ist das Ausgabeformat, keine garantierte Verarbeitungsleistung. Vision und
Kamerahardware bestimmen die effektive Bildrate; die Extension wiederholt bei kurzen
Lücken den letzten Frame. Die Vision-Analyse arbeitet auf einem verkleinerten Bild
standardmäßig mit maximal 768 Pixeln Breite; Analysebreite und Ausgabeformat sind einstellbar. Segmentierung kann
an Haaren, schnellen Bewegungen oder bei schlechtem Licht sichtbare Kanten erzeugen.
Audio und Aufnahme sind nicht Teil dieses Bootstraps. Für die Aktivierung eines
Developer-ID-Builds der virtuellen Kamera ist der oben beschriebene Notarisierungsweg erforderlich.
