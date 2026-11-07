---
layout: ../../layouts/DocsLayout.astro
title: "Kamera & Schutzbereiche"
description: "Vordergrund, Zubehör, Schutzpinsel und die Grenzen der Erkennung."
generated: true
---

## Vordergrund und Schutzbereiche

**Einstellungen → Bilderkennung → Zubehör → Person + Zubehör** ist bei Apple Vision der Standard. Die genaue Vision-Personenmaske
bildet die Basis; daran wird Zubehör gezielt ergänzt. Allgemeine Vision-Instanzen
werden nicht mehr pauschal übernommen, damit Tür oder Whiteboard bei wechselnder
Erkennung nicht als neue Vordergrundobjekte erscheinen. **Nur Person** verwendet
dieselbe Personenmaske ohne die automatische Zubehör-Ergänzung.

**Stuhl & Mikrofon ergänzen** ist im Objektmodus standardmäßig aktiv. Ein lokaler
Algorithmus sucht zusammenhängende dunkle, wenig gesättigte Flächen nahe der bereits
erkannten Person. Schmale farbige Komponenten ergänzen beispielsweise ein Kabel;
kurze Verbindungsstücke überbrücken helle Metallteile. Neue unabhängige Zubehörbereiche
benötigen mindestens drei aufeinanderfolgende Beobachtungen über mindestens 100 ms.
Bestätigtes Zubehör bleibt bei positiver Erkennung auch bei Farbsprüngen erhalten;
seine Farbreferenz folgt laufenden Belichtungsänderungen. Ausblenden benötigt mindestens
drei negative Beobachtungen über 200 ms. Bei deutlich anderem freigelegtem Hintergrund
reichen zwei negative Beobachtungen über mindestens 60 ms. Eine Wiedererkennung vor
der Freigabe gilt sofort. Die Personenmaske selbst wird weder verzögert noch mit alten
Kopfkonturen überblendet.

Bewegte Komponenten übernehmen die bestehende Bestätigung in einem
begrenzten Randbereich (2 % der Analysebreite), wenn mindestens 40 % der aktuellen
Komponente mit farblich passenden bestätigten Pixeln überlappen. Unabhängige neue
Bereiche durchlaufen weiterhin die anfängliche Mehrbildprüfung. Szenenwechsel werden
an Hintergrundpixeln außerhalb der aktuellen und vorherigen Personenmaske sowie des
Zubehörs gemessen, damit Personenbewegungen nicht die gesamte Zubehörhistorie löschen.

Die Zubehör-Bestätigung bleibt auch dann bestehen, wenn Vision
dasselbe Objekt zwischenzeitlich zur vollständig opaken Personenmaske zählt.
Die akzeptierten Objektkomponenten liefern dafür eigene Evidenz unabhängig vom
Personenalpha. Fällt etwa das Mikrofon später wieder aus der Personenmaske heraus,
ist seine Zubehörmaske bereits bestätigt. Personenalpha allein erzeugt dabei keine
Zubehörhistorie; bestätigte Gegenbelege, fehlender Personenanker und die Reset-Regeln bleiben wirksam.

Komponenten benötigen mehrere Stützpixel im Bereich des Oberkörpers. Kleine dunkle
Flecken und Striche werden nicht als eigenständiges Zubehör ergänzt. Bei zu großen
Erweiterungen werden einzelne Kandidaten abgelehnt, statt die gesamte Zubehörmaske
gleichzeitig aus- und wieder einzuschalten. Die Historie wird bei Stop/Start,
Modus-/Hintergrundwechsel, Zubehör-Umschaltung, neuer Quellgröße, Szenenwechsel,
Segmentierungsfehlern und längeren Frame-Pausen zurückgesetzt. Es werden keine
Koordinaten oder Farben aus dem Testfoto als feste Maske übernommen.

Die Ergänzung ist eine Erscheinungsheuristik, keine semantische Stuhl- oder
Mikrofonerkennung. Große zusätzliche Flächen und Verbindungen zum oberen Bildrand
werden verworfen; dennoch können kleine nahe dunkle Raumobjekte mit aufgenommen
werden. Bei dunklem Hintergrund den Schalter ausschalten oder auf **Nur Person**
mit gezielten Schutzmarkierungen wechseln.

Falls ein Gegenstand verschwindet: **Bereiche behalten** einschalten und im
Originalbild mit dem Pinsel darübermalen. **Pinselgröße**, **Rückgängig** und
**Löschen** korrigieren die Markierung. Anschließend den Bearbeitungsmodus ausschalten;
die Markierungen bleiben aktiv. Die virtuelle Kamera erhält auch während des Markierens
weiter das gefilterte Bild. Schutzbereiche sind feste Bildbereiche und folgen keinen
Objekten: Darin bleibt das gesamte Original sichtbar, einschließlich Raumhintergrund.
Nach einem Kameraschwenk die Markierungen korrigieren; ein Wechsel der Kamera löscht sie.

Die Statuszeile zeigt das gewählte Ausgabeformat, die tatsächliche Eingangsauflösung
und die gemessene Verarbeitungsbildrate getrennt an.

### Auflösung und FPS

Unter **Einstellungen → Ausgabe** stehen 1280 × 720, 1920 × 1080, 2560 × 1440 und
3840 × 2160 sowie 15, 24, 25, 30 und 60 FPS zur Auswahl. Änderungen sind bei gestoppter
Kamera möglich und bleiben gespeichert. Die App wählt ein passendes Hardwareformat;
bei einer kleineren Kamera wird das Bild auf das gewählte Ausgabeformat skaliert.
Die tatsächlich erreichbare Bildrate hängt von Kamera, Modell und Mac ab. Die UI-Vorschau
bleibt zur Entlastung auf höchstens 15 FPS begrenzt.

Die Kameraerweiterung meldet alle unterstützten Formate und Bildraten an Video-Apps.
Der Producer setzt das bevorzugte Format. Video-Apps können ihr eigenes Empfangsformat
aushandeln; die Erweiterung skaliert bei Bedarf. Nach einem Formatwechsel die Kamera
in der Video-App gegebenenfalls neu öffnen. Eine bereits installierte Erweiterung nach
diesem Update erneut aktivieren, damit sie die zusätzlichen Formate bereitstellt.
