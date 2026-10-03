#!/usr/bin/env node
// Downloads every question in the College Board SAT Suite Question Bank for one
// exam, with answers and explanations, and writes the files the website loads:
//   data/questions-rw-*.js    Reading and Writing, one file per domain
//   data/questions-math-*.js  Math, one file per domain
//
// Usage (Node 18 or newer, no npm install needed):
//   node scripts/fetch-questions.mjs                 PSAT/NMSQT & PSAT 10 (default)
//   node scripts/fetch-questions.mjs --exam psat89   PSAT 8/9
//   node scripts/fetch-questions.mjs --exam sat      SAT
// Options:
//   --concurrency N   parallel requests (default 6)
//   --limit N         only fetch the first N questions per section (for testing)
//   --no-images       keep image links instead of embedding images in the data
//   --fresh           ignore the download cache in .cache/
//
// Downloads are cached in .cache/, so if the script stops partway you can run it
// again and it picks up where it left off.

import { mkdir, readdir, readFile, rm, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DATA_DIR = path.join(ROOT, "data");
const CACHE_DIR = path.join(ROOT, ".cache");

const API = (process.env.CB_API_BASE || "https://qbank-api.collegeboard.org/msreportingquestionbank-prod/questionbank/digital").replace(/\/$/, "");
const DISCLOSED = (process.env.CB_DISCLOSED_BASE || "https://saic.collegeboard.org/disclosed").replace(/\/$/, "");
const SITE = "https://satsuitequestionbank.collegeboard.org";

const EXAMS = {
  psat: { id: 100, name: "PSAT/NMSQT & PSAT 10" },
  psat89: { id: 102, name: "PSAT 8/9" },
  sat: { id: 99, name: "SAT" },
};
const TESTS = [
  { id: 1, section: "rw", name: "Reading and Writing", domains: "INI,CAS,EOI,SEC" },
  { id: 2, section: "math", name: "Math", domains: "H,P,Q,S" },
];

// ---------------------------------------------------------------------------
// Arguments
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);
const flag = (name) => args.includes("--" + name);
const opt = (name, fallback) => {
  const i = args.indexOf("--" + name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const examKey = opt("exam", "psat");
const exam = EXAMS[examKey];
if (!exam) {
  console.error(`Unknown --exam "${examKey}". Use one of: ${Object.keys(EXAMS).join(", ")}`);
  process.exit(1);
}
const CONCURRENCY = Math.max(1, +opt("concurrency", 6) || 6);
const LIMIT = +opt("limit", 0) || 0;
const INLINE_IMAGES = !flag("no-images");
const FRESH = flag("fresh");

// ---------------------------------------------------------------------------
// HTTP with retries and an on-disk cache
// ---------------------------------------------------------------------------
const HEADERS = {
  "Content-Type": "application/json",
  Accept: "application/json, text/plain, */*",
  Origin: SITE,
  Referer: SITE + "/",
  "User-Agent": "Mozilla/5.0 (psat-prep question downloader)",
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function request(url, init = {}, tries = 5) {
  let lastErr;
  for (let attempt = 0; attempt < tries; attempt++) {
    try {
      const headers = Object.fromEntries(Object.entries({ ...HEADERS, ...(init.headers || {}) }).filter(([, v]) => v != null));
      const res = await fetch(url, { ...init, headers });
      if (res.ok) return res;
      if (res.status === 404) throw Object.assign(new Error(`404 Not Found: ${url}`), { fatal: true });
      lastErr = new Error(`HTTP ${res.status} from ${url}`);
      if (res.status < 500 && res.status !== 429) throw Object.assign(lastErr, { fatal: true });
    } catch (err) {
      if (err.fatal) throw err;
      lastErr = err;
    }
    await sleep(1000 * 2 ** attempt + Math.random() * 500);
  }
  throw lastErr;
}
async function cached(name, load) {
  const file = path.join(CACHE_DIR, name);
  if (!FRESH && existsSync(file)) {
    try {
      return JSON.parse(await readFile(file, "utf8"));
    } catch {
      /* corrupt cache entry: download again */
    }
  }
  const value = await load();
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, JSON.stringify(value));
  return value;
}
const postJson = async (url, body) => (await request(url, { method: "POST", body: JSON.stringify(body) })).json();
const getJson = async (url) => (await request(url, { method: "GET", headers: { "Content-Type": undefined } })).json();

async function pool(items, worker) {
  let next = 0;
  let done = 0;
  const results = new Array(items.length);
  async function run() {
    while (next < items.length) {
      const i = next++;
      results[i] = await worker(items[i], i);
      done++;
      if (done % 50 === 0 || done === items.length) process.stdout.write(`\r  ${done}/${items.length}`);
    }
  }
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, items.length) }, run));
  process.stdout.write("\n");
  return results;
}

// ---------------------------------------------------------------------------
// HTML clean-up
// ---------------------------------------------------------------------------
function sanitize(html) {
  return compactMarkup(
    String(html || "")
      .replace(/<script\b[\s\S]*?<\/script>/gi, "")
      .replace(/\son[a-z]+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)/gi, "")
      .replace(/(href|src)\s*=\s*(["'])\s*javascript:[^"']*\2/gi, '$1="#"')
      .trim()
  );
}
// Graphs are verbose SVG; drop the whitespace between tags and trim coordinates
// to two decimals. MathML only loses whitespace (its numbers are content).
function compactMarkup(html) {
  return html
    .replace(/<svg\b[\s\S]*?<\/svg>/gi, (b) => b.replace(/>\s+</g, "><").replace(/\s{2,}/g, " ").replace(/(\d\.\d{2})\d+/g, "$1"))
    .replace(/<math\b[\s\S]*?<\/math>/gi, (b) => b.replace(/>\s+</g, "><"));
}
const imageCache = new Map();
async function inlineImages(html, base) {
  if (!INLINE_IMAGES || !html || !/<img\b/i.test(html)) return html;
  const srcs = [...html.matchAll(/<img\b[^>]*?\bsrc\s*=\s*(["'])(.*?)\1/gi)].map((m) => m[2]).filter((s) => s && !s.startsWith("data:"));
  for (const src of new Set(srcs)) {
    let abs;
    try {
      abs = new URL(src, base).href;
    } catch {
      continue;
    }
    if (!imageCache.has(abs)) {
      imageCache.set(
        abs,
        (async () => {
          try {
            const res = await request(abs, { method: "GET", headers: { "Content-Type": undefined, Accept: "image/*" } }, 3);
            const type = (res.headers.get("content-type") || "image/png").split(";")[0];
            const buf = Buffer.from(await res.arrayBuffer());
            return `data:${type};base64,${buf.toString("base64")}`;
          } catch {
            return null;
          }
        })()
      );
    }
    const data = await imageCache.get(abs);
    if (data) html = html.split(src).join(data);
  }
  return html;
}

// Plain text from a rationale. Simple MathML fractions become a/b, and math
// drawn as images is replaced by its alt text ("the fraction 3 over 2").
function altToText(alt) {
  return String(alt)
    .replace(/the fraction (negative )?([\d.]+) over ([\d.]+)/gi, (m, neg, a, b) => (neg ? "-" : "") + a + "/" + b)
    .replace(/negative\s+([\d.])/gi, "-$1")
    .replace(/,?\s*end fraction/gi, "");
}
function rationaleText(html) {
  return String(html || "")
    .replace(/<img\b[^>]*?\balt\s*=\s*(["'])(.*?)\1[^>]*>/gi, (m, q, alt) => " " + altToText(alt) + " ")
    .replace(/<math\b[^>]*?\balttext\s*=\s*(["'])(.*?)\1[^>]*>[\s\S]*?<\/math>/gi, (m, q, alt) => " " + altToText(alt.replace(/\bminus\b/g, "-")) + " ")
    .replace(/<mfrac[^>]*>\s*<mn>([^<]*)<\/mn>\s*<mn>([^<]*)<\/mn>\s*<\/mfrac>/gi, "$1/$2")
    .replace(/<mo>\s*(?:−|&minus;|-)\s*<\/mo>/gi, "-")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&minus;|−/g, "-")
    .replace(/\s+/g, " ")
    .trim();
}
const NUM = String.raw`-?\s?(?:\d+\.?\d*|\.\d+)(?:\s?\/\s?(?:\d+\.?\d*|\.\d+))?`;
// Student-produced response answers, read from the explanation when the data
// doesn't list them ("The correct answer is 3/2. Note that 3/2 and 1.5 are
// examples of ways to enter a correct answer.").
function answersFromRationale(html) {
  const text = rationaleText(html);
  const clean = (v) => v.replace(/\s+/g, "").replace(/\.$/, "");
  const out = [];
  const main = text.match(new RegExp("correct answer is\\s+(" + NUM + ")", "i"));
  if (main) out.push(clean(main[1]));
  const note = text.match(/Note that (.+?) (?:are|is) (?:examples?|an example) of ways? to enter a correct answer/i);
  if (note) {
    for (const part of note[1].split(/\s*,\s*(?:and\s+|or\s+)?|\s+(?:and|or)\s+/)) {
      const v = clean(part.trim());
      if (/^-?(?:\d+\.?\d*|\.\d+)(?:\/(?:\d+\.?\d*|\.\d+))?$/.test(v)) out.push(v);
    }
  }
  return [...new Set(out)];
}
// Multiple-choice answer from the explanation ("Choice B is correct").
function letterFromRationale(html) {
  const m = rationaleText(html).match(/Choice ([A-H]) is (?:the )?(?:correct|best)/i);
  return m ? [m[1].toUpperCase()] : [];
}
function splitAnswers(value) {
  const list = Array.isArray(value) ? value : value == null ? [] : [value];
  return [...new Set(list.flatMap((v) => String(v).split(",")).map((v) => v.trim()).filter(Boolean))];
}

// ---------------------------------------------------------------------------
// Normalizing the two formats the question bank uses
// ---------------------------------------------------------------------------
function baseRecord(meta, test) {
  return {
    id: String(meta.questionId || meta.external_id || meta.ibn),
    section: test.section,
    domainCode: meta.primary_class_cd || "",
    domain: String(meta.primary_class_cd_desc || "").trim(),
    skillCode: meta.skill_cd || "",
    skill: String(meta.skill_desc || "").trim(),
    difficulty: meta.difficulty || "",
    scoreBand: meta.score_band_range_cd || null,
    programs: meta.pPcc || meta.program || "",
  };
}

// Newer questions: POST get-question {external_id}
async function fromApi(meta, test, d) {
  const optsRaw = d.answerOptions || d.answer_options || [];
  const options = Array.isArray(optsRaw) ? optsRaw : Object.values(optsRaw);
  const isSpr = String(d.type || "").toLowerCase() === "spr" || options.length === 0;
  const rec = baseRecord(meta, test);
  rec.type = isSpr ? "spr" : "mcq";
  rec.stimulus = await inlineImages(sanitize(d.stimulus), API);
  rec.stem = await inlineImages(sanitize(d.stem), API);
  rec.choices = [];
  for (const o of options) rec.choices.push(await inlineImages(sanitize(o.content ?? o.body ?? ""), API));
  rec.rationale = await inlineImages(sanitize(d.rationale), API);
  if (isSpr) {
    rec.answer = splitAnswers(d.correct_answer);
    if (!rec.answer.length) rec.answer = answersFromRationale(d.rationale);
  } else {
    let letters = splitAnswers(d.correct_answer).map((a) => a.toUpperCase()).filter((a) => /^[A-H]$/.test(a));
    if (!letters.length && Array.isArray(d.keys)) {
      letters = d.keys.map((k) => options.findIndex((o) => o.id === k)).filter((i) => i >= 0).map((i) => "ABCDEFGH"[i]);
    }
    rec.answer = letters.length ? letters.slice(0, 1) : letterFromRationale(d.rationale);
  }
  return rec;
}

// Older, publicly disclosed questions: GET saic.collegeboard.org/disclosed/{ibn}.json
async function fromDisclosed(meta, test, raw) {
  const d = Array.isArray(raw) ? raw[0] : raw;
  const ans = (d && d.answer) || {};
  const choicesObj = ans.choices || {};
  const keys = Object.keys(choicesObj).sort();
  const style = String(ans.style || "").toLowerCase();
  const isSpr = keys.length === 0 || style.includes("spr") || style.includes("produced");
  const rec = baseRecord(meta, test);
  rec.type = isSpr ? "spr" : "mcq";
  rec.stimulus = await inlineImages(sanitize(d.body), DISCLOSED + "/");
  rec.stem = await inlineImages(sanitize(d.prompt), DISCLOSED + "/");
  rec.choices = [];
  for (const k of keys) {
    const c = choicesObj[k];
    rec.choices.push(await inlineImages(sanitize(typeof c === "string" ? c : c.body ?? c.content ?? ""), DISCLOSED + "/"));
  }
  rec.rationale = await inlineImages(sanitize(ans.rationale || d.rationale), DISCLOSED + "/");
  if (isSpr) {
    rec.answer = splitAnswers(ans.correct_answer ?? ans.correct_answers ?? ans.answers);
    if (!rec.answer.length) rec.answer = answersFromRationale(ans.rationale || d.rationale);
  } else {
    const k = String(ans.correct_choice || "").toLowerCase();
    const i = keys.indexOf(k);
    rec.answer = i >= 0 ? ["ABCDEFGH"[i]] : letterFromRationale(ans.rationale || d.rationale);
  }
  return rec;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function fetchSection(test) {
  console.log(`\n${exam.name} · ${test.name}`);
  const list = await cached(`list-${exam.id}-${test.id}.json`, () => postJson(`${API}/get-questions`, { asmtEventId: exam.id, test: test.id, domain: test.domains }));
  if (!Array.isArray(list)) throw new Error(`Unexpected question list format: ${JSON.stringify(list).slice(0, 200)}`);
  const seen = new Set();
  let metas = list.filter((m) => {
    const id = m && (m.questionId || m.external_id || m.ibn);
    if (!id || seen.has(id)) return false;
    seen.add(id);
    return true;
  });
  if (LIMIT) metas = metas.slice(0, LIMIT);
  console.log(`  ${metas.length} questions listed`);

  const failures = [];
  const records = await pool(metas, async (meta) => {
    try {
      let rec;
      if (meta.external_id) {
        const d = await cached(`q/${meta.external_id}.json`, () => postJson(`${API}/get-question`, { external_id: meta.external_id }));
        rec = await fromApi(meta, test, d);
      } else if (meta.ibn) {
        const d = await cached(`ibn/${meta.ibn}.json`, () => getJson(`${DISCLOSED}/${encodeURIComponent(meta.ibn)}.json`));
        rec = await fromDisclosed(meta, test, d);
      } else {
        throw new Error("no external_id or ibn");
      }
      if (!rec.answer.length) throw new Error("couldn't find the correct answer");
      if (rec.type === "mcq" && rec.choices.length < 2) throw new Error("missing answer choices");
      return rec;
    } catch (err) {
      failures.push({ id: meta.questionId, reason: err.message });
      return null;
    }
  });
  const good = records.filter(Boolean);
  const order = { E: 0, M: 1, H: 2 };
  good.sort((a, b) => a.domainCode.localeCompare(b.domainCode) || a.skill.localeCompare(b.skill) || (order[a.difficulty] ?? 3) - (order[b.difficulty] ?? 3) || a.id.localeCompare(b.id));
  console.log(`  ${good.length} saved${failures.length ? `, ${failures.length} skipped` : ""}`);
  for (const f of failures.slice(0, 10)) console.log(`    skipped ${f.id}: ${f.reason}`);
  if (failures.length > 10) console.log(`    …and ${failures.length - 10} more`);
  return good;
}

// One file per domain keeps each file small enough to host anywhere.
const domainFile = (section, code) => `questions-${section}-${String(code || "other").toLowerCase().replace(/[^a-z0-9]/g, "")}.js`;
const EXPECTED_FILES = TESTS.flatMap((t) => t.domains.split(",").map((c) => domainFile(t.section, c)));

async function main() {
  const info = { exam: exam.name, asmtEventId: exam.id, fetchedAt: new Date().toISOString(), source: SITE };
  await mkdir(DATA_DIR, { recursive: true });
  const sections = [];
  for (const test of TESTS) sections.push([test, await fetchSection(test)]);
  // Only replace the old files once everything downloaded.
  for (const f of await readdir(DATA_DIR)) if (/^questions-.*\.js$/.test(f)) await rm(path.join(DATA_DIR, f));
  let total = 0;
  for (const [test, questions] of sections) {
    total += questions.length;
    const groups = new Map();
    for (const q of questions) {
      const file = domainFile(test.section, q.domainCode);
      if (!groups.has(file)) groups.set(file, { domain: q.domain, list: [] });
      groups.get(file).list.push(q);
    }
    for (const [file, { domain, list }] of groups) {
      const out =
        `// Generated by scripts/fetch-questions.mjs on ${info.fetchedAt.slice(0, 10)}.\n` +
        `// Source: College Board SAT Suite Question Bank (${exam.name}), ${test.name}: ${domain}. Questions and explanations are College Board's.\n` +
        `// Re-run the script to refresh. Don't edit by hand.\n` +
        `window.PSAT_BANK_INFO = ${JSON.stringify(info)};\n` +
        `window.PSAT_BANK = window.PSAT_BANK || [];\n` +
        `window.PSAT_BANK.push.apply(window.PSAT_BANK, ${JSON.stringify(list)});\n`;
      await writeFile(path.join(DATA_DIR, file), out);
      console.log(`  wrote data/${file}: ${list.length} questions, ${(Buffer.byteLength(out) / 1048576).toFixed(1)} MB`);
      if (!EXPECTED_FILES.includes(file)) console.log(`  note: index.html doesn't load ${file} yet; add a <script> tag for it.`);
    }
  }
  console.log(`\nDone: ${total} questions. Open index.html to start practicing.`);
}

main().catch((err) => {
  console.error("\nDownload failed:", err.message);
  if (/fetch failed|ENOTFOUND|ECONNREFUSED|ETIMEDOUT|403/i.test(String(err.message) + String(err.cause || ""))) {
    console.error("Check your internet connection. If you're on a school network, College Board's question bank may be blocked; try another network.");
  }
  process.exit(1);
});
