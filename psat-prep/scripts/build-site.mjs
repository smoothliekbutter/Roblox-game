#!/usr/bin/env node
// Builds the public website into dist/ (served from the gh-pages branch).
//
// The question files in data/ embed every math picture as base64 text, which
// keeps the site working as a single folder (and inside a claude.ai artifact)
// but means visitors download ~8 MB of pictures before they can start. Here
// each picture becomes its own file in dist/data/img/, so a phone only
// downloads the pictures for the questions it actually opens.
//
// Usage: node scripts/build-site.mjs [--out dist]

import { createHash } from "node:crypto";
import { copyFile, mkdir, readdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const outArg = args.indexOf("--out");
const OUT = path.resolve(ROOT, outArg >= 0 && args[outArg + 1] ? args[outArg + 1] : "dist");
const EXT = { png: "png", jpeg: "jpg", jpg: "jpg", gif: "gif", webp: "webp", "svg+xml": "svg" };

await rm(OUT, { recursive: true, force: true });
await mkdir(path.join(OUT, "data", "img"), { recursive: true });
for (const f of ["index.html", "styles.css", "app.js", "data/sample-questions.js"]) await copyFile(path.join(ROOT, f), path.join(OUT, f));

const written = new Set();
let imageBytes = 0;
async function extractImages(html) {
  if (!html || !html.includes("data:image/")) return html;
  const found = [...html.matchAll(/data:image\/([a-z+]+);base64,([A-Za-z0-9+/=]+)/g)];
  for (const [uri, type, b64] of found) {
    const ext = EXT[type];
    if (!ext) continue;
    const name = createHash("sha1").update(b64).digest("hex").slice(0, 16) + "." + ext;
    if (!written.has(name)) {
      const buf = Buffer.from(b64, "base64");
      await writeFile(path.join(OUT, "data", "img", name), buf);
      written.add(name);
      imageBytes += buf.length;
    }
    html = html.split(uri).join("data/img/" + name);
  }
  // Pictures far down a long explanation can wait until they're scrolled to.
  return html.replace(/<img\b(?![^>]*\bloading=)/gi, '<img loading="lazy" decoding="async"');
}

let before = 0;
let after = 0;
let count = 0;
for (const file of (await readdir(path.join(ROOT, "data"))).filter((f) => /^questions-.*\.js$/.test(f)).sort()) {
  const src = await readFile(path.join(ROOT, "data", file), "utf8");
  const sandbox = { window: {} };
  vm.runInNewContext(src, sandbox, { filename: file });
  const list = sandbox.window.PSAT_BANK || [];
  for (const q of list) {
    for (const key of ["stimulus", "stem", "rationale"]) q[key] = await extractImages(q[key]);
    q.choices = await Promise.all((q.choices || []).map(extractImages));
  }
  const header = src.split("\n").filter((l) => l.startsWith("//")).join("\n");
  const out =
    `${header}\n// Website build: pictures live in data/img/ (made by scripts/build-site.mjs).\n` +
    (sandbox.window.PSAT_BANK_INFO ? `window.PSAT_BANK_INFO = ${JSON.stringify(sandbox.window.PSAT_BANK_INFO)};\n` : "") +
    `window.PSAT_BANK = window.PSAT_BANK || [];\n` +
    (list.length ? `window.PSAT_BANK.push.apply(window.PSAT_BANK, ${JSON.stringify(list)});\n` : "");
  await writeFile(path.join(OUT, "data", file), out);
  before += Buffer.byteLength(src);
  after += Buffer.byteLength(out);
  count += list.length;
}

await writeFile(path.join(OUT, ".nojekyll"), "");
await writeFile(
  path.join(OUT, "README.md"),
  "# PSAT Prep website\n\nThis branch is the published copy of the PSAT Prep site, served by GitHub Pages at\nhttps://smoothliekbutter.github.io/Roblox-game/\n\nDon't edit it by hand. It's built from `psat-prep/` on the `claude/gifted-cori-osoeco` branch by\n`scripts/build-site.mjs` and published with `scripts/publish-site.sh`.\n"
);

const mb = (n) => (n / 1048576).toFixed(1) + " MB";
console.log(`Built ${OUT}: ${count} questions, ${written.size} pictures (${mb(imageBytes)}) moved to data/img/.`);
console.log(`Question files: ${mb(before)} -> ${mb(after)}.`);
