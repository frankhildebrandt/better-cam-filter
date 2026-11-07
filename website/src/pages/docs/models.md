---
layout: ../../layouts/DocsLayout.astro
title: "Modelle & Masken"
description: "Apple Vision, U²-Net, eigene Core-ML-Modelle und Maskenkorrekturen."
generated: true
---

## Einstellungen und Modellauswahl

**Einstellungen …** unten in der Seitenleiste oder **BetterCam → Einstellungen …** (`⌘,`)
öffnet ein Fenster im Stil der macOS-Systemeinstellungen mit Kategorien und gruppierten Formularen:

- **Kamera:** gespeicherte Kameraquelle und aktueller Eingangsstatus.
- **Ausgabe:** Auflösung, Bildrate und Aktivierung der virtuellen Kamera.
- **Bilderkennung:** aktives Modell, Ausführungsparameter, Maskenoptimierung und Maskenvorschau.
- **Modelle:** Download-Katalog und Import eigener Core-ML-Modelle.
- **Hintergründe:** Generierungsprofile, Referenzbilder und Server-Verbindung.

Im Hauptfenster bleiben Start/Stopp, Hintergrundauswahl und Schutzmarkierungen direkt erreichbar.
Unter **Bilderkennung → Modell** stehen
**Apple Vision**, **U²-NetP**, **U²-Net** und eigene importierte Modelle zur Auswahl. Die Auswahl gilt für Vorschau
und virtuelle Kamera und bleibt nach einem Neustart erhalten.

Apple Vision ist der Standard und benötigt keinen Download. **U²-NetP** ist die
empfohlene kleine Alternative für einen ersten Live-Versuch; **U²-Net** ist die größere
Variante für einen Qualitätsvergleich. Die Auswahl eines noch nicht installierten
Modells oder **Herunterladen und verwenden** startet den Download mit Fortschritt und
Abbruchmöglichkeit. Erst nach Größen-/SHA-256-Prüfung, Kompilierung und erfolgreicher
Testinferenz wird das neue Modell aktiviert. Währenddessen bleibt die bisherige
Auswahl erhalten. Fehler und Abbrechen ändern sie nicht. Bereits heruntergeladene
Modelle bleiben gespeichert und lassen sich ohne erneuten Download auswählen.

Die Core-ML-Konvertierungen stammen aus [john-rocky/CoreML-Models](https://github.com/john-rocky/CoreML-Models#u2net),
das von den [U²-Net-Autoren](https://github.com/xuebinqin/U-2-Net) verlinkt wird. Beide
Modelle stehen unter [Apache-2.0](https://github.com/xuebinqin/U-2-Net/blob/master/LICENSE).
Die Modellkarte zeigt Dateigröße, Lizenz und Quelle. Downloads erfolgen direkt vom
verlinkten Google-Drive-Host; Kamerabilder werden nicht hochgeladen. Der Katalog enthält
feste Dateigrößen und Prüfsummen in `SegmentationModelCatalog.swift`.

Beide Modelle segmentieren allgemeine Vordergrundobjekte bildweise und besitzen
keine Videoverfolgung. Auf dem bereitgestellten Testbild bleiben Person und Mikrofon
erhalten; Stuhl und Mikrofonarm werden teilweise entfernt. Eine vollständige Erhaltung
dieser Gegenstände oder flackerfreie Masken ist damit nicht zugesagt. Schutzmarkierungen
bleiben verfügbar. Die Ausgabeauflösung wird separat gewählt; die Modellanalyse erfolgt bei
320 × 320 Pixeln. Die Bildrate hängt vom Mac und der gesamten Verarbeitung ab.

**Modell importieren …**
übernimmt ein eigenes Core-ML-Modell (`.mlmodel`, `.mlpackage` oder `.mlmodelc`),
prüft seine Schnittstelle und aktiviert es nach erfolgreichem Import. Ohne importiertes
Modell öffnet die Auswahl **Eigenes Modell importieren …** den Importdialog. Abbrechen und
fehlgeschlagene Importe behalten die bisherige Auswahl bei. Ein bereits importiertes
Modell lässt sich jederzeit wieder auswählen; Apple Vision bleibt parallel verfügbar.

Das Custom-Modell muss genau einen Bildeingang und eine einzelne Vordergrundmaske
liefern: ein Graustufenbild oder ein einkanaliges Array mit Form `[H, W]`, `[1, H, W]`
oder `[1, 1, H, W]` und Werten von 0 bis 1. Weiß beziehungsweise 1 bedeutet behalten,
Schwarz beziehungsweise 0 bedeutet Hintergrund. Das gesamte Kamerabild wird auf den
Modelleingang skaliert; die Maske wird anschließend auf dieselben Bildkoordinaten
abgebildet. Modelle mit mehreren Klassen, Bildprompts oder zusätzlichen Zuständen
benötigen einen eigenen Adapter. Für die sieben bekannten U²-Net-Ausgänge wird gezielt
die kombinierte Maske `out_p0` verwendet. Beliebige SAM-/PyTorch-Gewichte können nicht direkt
importiert werden. Die App enthält keine Modellgewichte; Katalogmodelle werden auf Wunsch geladen.

Kompilierung und Prüfung laufen außerhalb des UI-Threads. BetterCam speichert eigene
kompilierte Modellkopien unter `Application Support/BetterCam/Segmentation`; die
ursprüngliche Datei muss danach nicht mehr verfügbar sein. Die Verarbeitung läuft
lokal. Bei einem Fehler während der Modellanwendung erscheint die Fehlermeldung im
Kamerafenster; es erfolgt kein stiller Wechsel zu Apple Vision.

Bei Apple Vision lassen sich unter **Bilderkennung** Qualität (schnell, ausgewogen, präzise),
Analysebreite (256 bis 3840 Pixel oder volle Ausgabeauflösung), unterstützte Vision-Version
und bevorzugte Hintergrundverarbeitung einstellen. Hinzu kommen Erkennungsmodus und
Zubehör-Ergänzung. Diese Einstellungen bleiben gespeichert. Die Apple-Parameter gelten
auch für die optionale zusätzliche Personenerkennung bei eigenen Modellen.

Bei Core-ML-Modellen stehen pro Modell Recheneinheiten (automatisch, CPU, CPU/GPU oder
CPU/Neural Engine) und Eingangs-Skalierung (strecken, einpassen, ausfüllen) zur Verfügung.
Die Eingangsgröße und die Maskenausgänge sind durch die jeweilige Modelldatei vorgegeben.
Einpassen verwendet schwarze Ränder; Ausfüllen beschneidet den Eingang. Die Maske wird
mit der passenden inversen Transformation auf das Kamerabild zurückgeführt.
Die automatische Apple-Zubehör-Heuristik ist beim Custom-Modell ausgeschaltet.
Explizite Schutzmarkierungen gelten weiterhin für beide Varianten.

### Masken einstellen

Unter **Bilderkennung → Maske optimieren** gibt es gespeicherte Einstellungen pro
Modell, einschließlich Apple Vision. Apple beginnt mit **Unverändert**, um das bisherige Verhalten beizubehalten. Bei U²-Net ist **Ausgewogen** voreingestellt; das kleine U²-NetP
nutzt **Mehr Vordergrund**, weil es auf dem lokalen Testbild andernfalls auch im
Pullover deutlich durchsichtige Bereiche erzeugt. Neu manuell importierte Modelle
beginnen mit **Unverändert**, damit fertige Matting-Modelle ihre eigenen weichen
Alpha-Werte behalten. **Unverändert** schaltet Nachbearbeitung, zusätzliche
Personenerkennung und Stabilisierung vollständig aus.

- **Erkennungsschwelle:** Niedriger behält mehr schwach erkannte Arme und Zubehör,
  kann aber auch Raumobjekte aufnehmen. Höher entfernt mehr unsichere Bereiche.
- **Übergangsbreite:** Schmaler setzt erkannte Flächen früher auf vollständig opak;
  breiter lässt weichere, durchsichtige Übergänge zu. Die Wahrscheinlichkeitswerte
  werden zwischen `Schwelle − Breite/2` und `Schwelle + Breite/2` auf 0 bis 1 abgebildet.
- **Kantenkorrektur:** Positive Werte verkleinern die Maske gegen helle Säume,
  negative erweitern sie. Die Pixelangabe bezieht sich auf 1080 Pixel Ausgabehöhe.
- **Flackern reduzieren:** Hält zuvor sicher erkannten Vordergrund kurz fest, wenn
  die Bildfarbe am gleichen Ort weiterhin passt. Die Haltezeit beträgt höchstens
  120 ms bei 100 %. Neue Vordergrundflächen erscheinen sofort; eigene gehaltene
  Ausgaben verlängern die Historie nicht. Bei nachziehenden Konturen den Wert senken.
- **Person zusätzlich mit Apple erkennen:** Vereinigt die aktuelle Vision-Personenmaske
  mit der Objektmaske vor der Nachbearbeitung. Das kann fehlende Körperbereiche
  ergänzen und benötigt zusätzliche Rechenzeit. Es ist optional und standardmäßig aus.

**Maske nur in Vorschau anzeigen** zeigt Weiß für erhaltene Flächen, Schwarz für
Hintergrund und Grau für Durchsichtigkeit. Dafür muss die Hintergrundersetzung aktiv
sein. Die virtuelle Kamera bekommt weiterhin das gefilterte Farbbild. Der Schutzpinsel
zeigt beim Bearbeiten weiterhin das Original und hat Vorrang vor der Maskenvorschau.

Auf dem ursprünglichen, ungefilterten Testfoto reduzieren die neuen Vorgaben den
hellen Saum und durchsichtige Kleidungsbereiche; Mikrofon-Schaumstoff bleibt erhalten,
die geprüften Tür-/Whiteboardbereiche bleiben ausgeschlossen. Vollständig fehlende
Stuhl-/Arm-/Metallteile lassen sich durch Schwellwerte nicht zurückholen. Die
zusammengesetzte Bildschirmaufnahme liefert keinen Nachweis, dass schnelle Bewegungen
nun sauber freigestellt werden; dafür ist eine neue Live-Prüfung erforderlich.
