import { readFile, writeFile, mkdir } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const readme = await readFile(
  new URL("../../README.md", import.meta.url),
  "utf8",
);
const parts = [
  ...readme.matchAll(/^## (.+)\n([\s\S]*?)(?=^## |$(?![\s\S]))/gm),
];
const sections = new Map(parts.map(([, title, body]) => [title, body.trim()]));
const pages = [
  [
    "build",
    "Download & Installation",
    "BetterCam herunterladen, die virtuelle Kamera aktivieren oder die App selbst bauen.",
    ["Download und Installation", "Voraussetzungen", "Bauen und starten"],
  ],
  [
    "backgrounds",
    "Hintergründe & Codex",
    "Profile, Referenzbilder, Mediathek und die optionale Bildgenerierung.",
    ["Hintergründe mit Codex erzeugen"],
  ],
  [
    "models",
    "Modelle & Masken",
    "Apple Vision, U²-Net, eigene Core-ML-Modelle und Maskenkorrekturen.",
    ["Einstellungen und Modellauswahl"],
  ],
  [
    "camera",
    "Kamera & Schutzbereiche",
    "Vordergrund, Zubehör, Schutzpinsel und die Grenzen der Erkennung.",
    ["Vordergrund und Schutzbereiche"],
  ],
  [
    "architecture",
    "Architektur",
    "Capture, lokale Bildverarbeitung und die CoreMediaIO Camera Extension.",
    ["Architektur"],
  ],
  [
    "testing",
    "Tests & Diagnose",
    "Build-Prüfung, Swift-Tests, Maskendiagnose und manuelle Installationstests.",
    ["Prüfen"],
  ],
  [
    "research",
    "Modell-Recherche",
    "Recherche vom 7. November 2026: mögliche nächste Schritte für Segmentierung und Matting.",
    ["Recherche zu Segmentierung und Matting (7. November 2026)"],
  ],
  [
    "license",
    "Lizenz",
    "BetterCam unter MIT sowie die Lizenzbedingungen optionaler Modelle.",
    ["Lizenz"],
  ],
];
await mkdir(new URL("src/pages/docs/", root), { recursive: true });
for (const [slug, title, description, names] of pages) {
  const content = names
    .map((name) => {
      if (!sections.has(name))
        throw new Error(`README section missing: ${name}`);
      return `## ${name}\n\n${sections.get(name)}`;
    })
    .join("\n\n")
    .replace(/^```xcconfig$/gm, "```ini")
    .replace(
      /\]\((?!https?:|#)([^)]+)\)/g,
      "](https://github.com/frankhildebrandt/better-cam-filter/blob/main/$1)",
    );
  await writeFile(
    new URL(`src/pages/docs/${slug}.md`, root),
    `---\nlayout: ../../layouts/DocsLayout.astro\ntitle: ${JSON.stringify(title)}\ndescription: ${JSON.stringify(description)}\ngenerated: true\n---\n\n${content}\n`,
  );
}
console.log(`Synchronized ${pages.length} documentation pages from README.md.`);
