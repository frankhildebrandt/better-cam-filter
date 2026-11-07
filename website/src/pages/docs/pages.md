---
layout: ../../layouts/DocsLayout.astro
title: "Website & Pages-Build"
description: "Die Astro-Website entwickeln, Inhalte aktualisieren und automatisch auf GitHub Pages veröffentlichen."
---

Die Website liegt eigenständig unter `website/` und verwendet Astro im statischen Modus. Der Swift-/Xcode-Build bleibt davon unabhängig. Es gibt keine serverseitige Laufzeit und keine zusätzliche Client-Framework-Abhängigkeit.

## Lokal starten

Voraussetzung ist **Node.js 22.23.4 oder neuer**. Der Workflow verwendet Node.js 24.

```sh
cd website
npm ci
npm run docs:sync
npm run assets
npm run dev
```

Die lokale Website ist unter `http://localhost:4321/better-cam-filter/` erreichbar.

## Produktion bauen und prüfen

```sh
cd website
npm ci
npm run docs:sync
npm run check
npm run build
```

`npm run build` synchronisiert die technische Dokumentation aus der Projekt-README, bereitet die App-Icons und die Social-Grafik auf und baut die statischen Seiten nach `website/dist/`. Danach prüft ein lokaler Link-Check interne Seiten, Sprungmarken, Downloads und Assets. `npm run preview` stellt den fertigen Build lokal bereit.

## Inhalte pflegen

- Die technische Dokumentation unter `website/src/pages/docs/` wird für acht Seiten aus den jeweiligen Abschnitten der **README.md im Projektwurzelverzeichnis** übernommen. Änderungen dort vornehmen und `npm run docs:sync` ausführen. Die generierten Seiten sind mit `generated: true` markiert.
- Überblick und dieser Website-Leitfaden werden direkt in ihren Markdown-Dateien gepflegt.
- Landingpage: `website/src/pages/index.astro`.
- Marketingseite: `website/src/pages/marketing.astro`; herunterladbare Texte und Grafiken: `website/public/media/`.
- Gemeinsame Navigation und Pfade: `website/src/lib/site.ts`; Gestaltung: `website/src/styles/global.css`.
- Das App-Icon stammt aus dem vorhandenen macOS-Asset-Katalog. Die Social-PNG wird aus der versionierten SVG-Grafik erzeugt.

## Automatischer Pages-Workflow

`.github/workflows/pages.yml` führt auf Pull Requests den Website-Check und den vollständigen Build aus. Pushes auf `main` sowie manuelle Starts auf `main` veröffentlichen den geprüften Build über das offizielle GitHub-Pages-Artefakt. Der Deploy-Job verwendet die Umgebung `github-pages` und kurzlebige GitHub-Berechtigungen; ein persönlicher Token wird nicht benötigt.

Der Build-Job hat nur Leserechte. Ausschließlich der Deploy-Job erhält `pages: write` und `id-token: write`. Die Pages-Konfiguration erfolgt im Repository unter **Settings → Pages → Source: GitHub Actions**.

## Projektpfad und Suchmaschinen

In `astro.config.mjs` sind `site: 'https://frankhildebrandt.github.io'` und `base: '/better-cam-filter'` gesetzt. Interne Links und Assets verwenden diesen Basispfad auch bei lokalem Aufruf. Bei einem Repository- oder Domainwechsel diese Werte sowie die Sitemap-Adresse im Asset-Skript und den Link-Check anpassen.

Die Website liefert Canonical-URLs, Open-Graph-/Twitter-Metadaten mit PNG-Vorschaubild, eine Sitemap, `robots.txt` und eine eigene 404-Seite. Die Gestaltung verwendet Systemschriften und benötigt keine externen Font-Anfragen.

Grundlage: [Astro: GitHub-Pages-Deployment](https://docs.astro.build/en/guides/deploy/github/) und die [offiziellen GitHub-Pages-Actions](https://github.com/actions/deploy-pages).
