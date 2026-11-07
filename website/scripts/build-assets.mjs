import { readFile, copyFile, mkdir, writeFile } from "node:fs/promises";
import sharp from "sharp";
import { fileURLToPath } from "node:url";

const root = new URL("../", import.meta.url);
const media = new URL("public/media/", root);
await mkdir(media, { recursive: true });
const icon = new URL(
  "../../App/Assets.xcassets/AppIcon.appiconset/icon_1024.png",
  import.meta.url,
);
await copyFile(icon, new URL("bettercam-icon.png", media));
await sharp(await readFile(icon))
  .resize(128)
  .png()
  .toFile(fileURLToPath(new URL("icon-128.png", media)));
await sharp(await readFile(new URL("public/media/bettercam-social.svg", root)))
  .png()
  .toFile(fileURLToPath(new URL("bettercam-social.png", media)));
await copyFile(
  new URL("../../LICENSE", import.meta.url),
  new URL("LICENSE.txt", media),
);
await writeFile(
  new URL("public/robots.txt", root),
  "User-agent: *\nAllow: /\n\nSitemap: https://frankhildebrandt.github.io/better-cam-filter/sitemap-index.xml\n",
);
console.log("Prepared app icons, social PNG, license and robots.txt.");
