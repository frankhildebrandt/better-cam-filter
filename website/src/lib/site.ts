export const repository =
  "https://github.com/frankhildebrandt/better-cam-filter";
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
    title: "Build & Installation",
    description: "Xcode, Signierung, Notarisierung und die virtuelle Kamera.",
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
