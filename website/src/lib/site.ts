export const repository =
  "https://github.com/frankhildebrandt/better-cam-filter";
export const releaseVersion = "0.1.0";
export const releaseURL = `${repository}/releases/tag/v${releaseVersion}`;
export const downloadURL = `${repository}/releases/download/v${releaseVersion}/BetterCam-v${releaseVersion}-macos-universal.zip`;
export const screenshots = [
  {
    slug: "preview",
    title: "Dein Kamera-Ausgang",
    caption: "Hauptfenster mit gestoppter Kamera und ausgeblendeter Seitenleiste.",
    width: 1080,
    height: 680,
  },
  {
    slug: "camera",
    title: "Kamera auswählen",
    caption: "Kameraquelle und Status der aktuellen Sitzung.",
    width: 1800,
    height: 1456,
  },
  {
    slug: "output",
    title: "Ausgabe konfigurieren",
    caption: "Auflösung, Zielbildrate und Aktivierung der virtuellen Kamera.",
    width: 1800,
    height: 1456,
  },
  {
    slug: "gestures",
    title: "Gesten konfigurieren",
    caption: "Lokale Handerkennung und Zuordnungen für animierte Reactions.",
    width: 1800,
    height: 1456,
  },
  {
    slug: "recognition",
    title: "Bilderkennung anpassen",
    caption: "U²-Net, Recheneinheiten, Bildskalierung und Maskeneinstellungen.",
    width: 1800,
    height: 1456,
  },
  {
    slug: "models",
    title: "Modelle verwalten",
    caption: "Download-Katalog mit U²-NetP, U²-Net, Größen- und Lizenzangaben.",
    width: 1800,
    height: 1456,
  },
];
export const base = import.meta.env.BASE_URL.replace(/\/$/, "");
export const url = (path = "") => `${base}/${path.replace(/^\//, "")}`;

export const docs = [
  {
    slug: "",
    title: "Überblick",
    description: "Der Einstieg in BetterCam und diese Dokumentation.",
  },
  {
    slug: "build",
    title: "Download & Installation",
    description: "App herunterladen, virtuelle Kamera einrichten oder selbst bauen.",
  },
  {
    slug: "screenshots",
    title: "Screenshots",
    description: "Einblicke in BetterCam 0.1.0 und die aktuellen Einstellungen.",
  },
  {
    slug: "camera",
    title: "Kamera & Schutzbereiche",
    description: "Kamera bedienen, Zubehör erhalten und Bereiche markieren.",
  },
  {
    slug: "backgrounds",
    title: "Hintergründe & Codex",
    description: "Eigene Bilder, Profile und die optionale Bildgenerierung.",
  },
  {
    slug: "models",
    title: "Modelle & Masken",
    description:
      "Apple Vision, U²-Net und eigene Core-ML-Modelle konfigurieren.",
  },
  {
    slug: "architecture",
    title: "Architektur",
    description: "Von AVFoundation über die Verarbeitung zur Camera Extension.",
  },
  {
    slug: "testing",
    title: "Tests & Diagnose",
    description: "Build prüfen, Tests ausführen und Masken untersuchen.",
  },
  {
    slug: "research",
    title: "Modell-Recherche",
    description: "Einordnung möglicher künftiger Segmentierungsmodelle.",
  },
  {
    slug: "license",
    title: "Lizenz",
    description: "MIT-Lizenz und Hinweise zu optionalen Modellen.",
  },
  {
    slug: "pages",
    title: "Website & Pages-Build",
    description: "Astro lokal bauen und über GitHub Actions veröffentlichen.",
  },
];
