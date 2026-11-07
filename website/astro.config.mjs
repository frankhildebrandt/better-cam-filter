import { defineConfig } from "astro/config";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: "https://frankhildebrandt.github.io",
  base: "/better-cam-filter",
  output: "static",
  trailingSlash: "always",
  integrations: [sitemap()],
  markdown: { shikiConfig: { theme: "github-dark" } },
});
