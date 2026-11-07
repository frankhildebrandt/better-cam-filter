# BetterCam Website

Deutschsprachige Astro-Landingpage, technische Dokumentation und Marketing-Kit für
[GitHub Pages](https://frankhildebrandt.github.io/better-cam-filter/).

Voraussetzung: Node.js >= 22.23.4 (GitHub Actions: Node.js 24).

```sh
cd website
npm ci
npm run docs:sync
npm run assets
npm run dev
```

Startseite: <http://localhost:4321/better-cam-filter/>

```sh
npm run check
npm run build
```

Der Build aktualisiert die acht technischen Dokumentationsseiten aus der
Projekt-README, bereitet Icons und Social-PNG vor und prüft alle internen Links,
Sprungmarken und Assets im statischen Ergebnis unter `dist/`.

Technische Inhalte in der **Projekt-README** bearbeiten; `npm run docs:sync`
überschreibt die mit `generated: true` markierten Seiten. Überblick, Pages-Anleitung,
Screenshot-Galerie, Landingpage und Marketingseite werden direkt in `src/pages/` gepflegt.

Der Workflow `.github/workflows/pages.yml` prüft Pull Requests und veröffentlicht
Änderungen auf `main` über GitHub Actions. Im Repository muss **Settings → Pages →
Source: GitHub Actions** aktiv sein. Ein manueller Workflow-Start veröffentlicht nur
auf `main`. Es werden keine Apple-Zertifikate oder zusätzlichen Deployment-Secrets
benötigt; der macOS-App-Build bleibt unabhängig.

Marketing-Downloads liegen in `public/media/`: Original-App-Icon, Social-Grafik
(PNG/SVG), deutsche und englische Produkttexte sowie MIT-Lizenztext. Das App-Icon und
die PNG-Social-Grafik werden bei jedem Build reproduzierbar vorbereitet. Die
Studiografik ist eine Illustration und wird auf der Seite entsprechend bezeichnet.

`astro.config.mjs`, `scripts/check-links.mjs` und `scripts/build-assets.mjs` enthalten
die GitHub-Pages-Domain und den Projektpfad. Bei einem Domain-/Repositorywechsel
gemeinsam anpassen. Interne Links verwenden den zentralen `url()`-Helper.

## App-Download und Screenshots

Version und Release-/Download-URLs liegen zentral in `src/lib/site.ts`. Der Download
führt zum öffentlichen GitHub-Release. Die Website verteilt selbst kein App-Paket.

`public/media/screenshots/bettercam-0.1.0-*.png` enthält sechs echte Aufnahmen des
0.1.0-Release-Builds. Kamera gestoppt, Hauptfenster-Seitenleiste ausgeblendet:
Es sind keine persönlichen Hintergründe, Mediathek-Miniaturen oder Kamerabilder
enthalten. Die Einstellungen zeigen Kamera, Ausgabe, Gesten, Bilderkennung und Modelle.
Die Galerie dient der UI-Dokumentation, nicht als Leistungs- oder Qualitätsnachweis.
Neue Screenshots vor dem Einchecken vollständig auf persönliche Bildinhalte prüfen.
