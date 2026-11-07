import { readdir, readFile, stat } from "node:fs/promises";
import { resolve, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

// Verify the deployed project subpath, including Markdown links and local downloads.
const directory = fileURLToPath(new URL("../dist/", import.meta.url));
const origin = "https://frankhildebrandt.github.io";
const base = "/better-cam-filter/";
const htmlFiles = [];
async function walk(path) {
  for (const entry of await readdir(path, { withFileTypes: true })) {
    const file = join(path, entry.name);
    if (entry.isDirectory()) await walk(file);
    else if (file.endsWith(".html")) htmlFiles.push(file);
  }
}
await walk(directory);
if (htmlFiles.length < 12)
  throw new Error(
    "Expected landing page, documentation, media kit and 404 page.",
  );
const errors = [];
let checked = 0;
for (const file of htmlFiles) {
  const html = await readFile(file, "utf8");
  const pagePath = relative(directory, file).replace(/index\.html$/, "");
  const page = new URL(base + pagePath, origin);
  for (const [, raw] of html.matchAll(/\b(?:href|src)="([^"]+)"/g)) {
    const value = raw.replaceAll("&amp;", "&");
    if (/^(?:mailto:|tel:|data:)/.test(value)) continue;
    const target = new URL(value, page);
    if (target.origin !== origin) continue;
    if (!target.pathname.startsWith(base)) {
      errors.push(`${pagePath}: URL escapes GitHub Pages base: ${value}`);
      continue;
    }
    let local = resolve(
      directory,
      decodeURIComponent(target.pathname.slice(base.length)),
    );
    if (!local.startsWith(resolve(directory)))
      throw new Error(`Path escapes dist: ${value}`);
    try {
      if ((await stat(local)).isDirectory()) local = join(local, "index.html");
      await stat(local);
      if (target.hash && local.endsWith(".html")) {
        const document = await readFile(local, "utf8");
        const id = decodeURIComponent(target.hash.slice(1));
        if (!document.includes(`id="${id}"`))
          throw new Error(`Missing anchor: ${id}`);
      }
      checked++;
    } catch (error) {
      errors.push(`${pagePath}: ${value} (${error.message})`);
    }
  }
  if (!html.includes('<html lang="de">'))
    errors.push(`${pagePath}: German document language missing`);
  if (!html.includes('property="og:image"'))
    errors.push(`${pagePath}: Open Graph image missing`);
  if (!html.includes('name="description"'))
    errors.push(`${pagePath}: SEO description missing`);
}
if (errors.length) throw new Error(errors.join("\n"));
console.log(
  `Verified ${checked} local links/assets/anchors across ${htmlFiles.length} HTML pages under ${base}.`,
);
