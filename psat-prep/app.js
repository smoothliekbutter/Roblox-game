/* PSAT Prep: practice questions with explanations, plus skill analytics.
   Plain JavaScript, no build step. Works from file://, any static host, or a
   claude.ai artifact (where progress also syncs to the viewer's account). */
(function () {
  "use strict";

  // ---------------------------------------------------------------------------
  // Exam blueprint (PSAT/NMSQT & PSAT 10). Domain weights are each domain's
  // approximate share of its section in College Board's test specifications.
  // ---------------------------------------------------------------------------
  const SECTIONS = {
    rw: { key: "rw", name: "Reading and Writing", short: "R&W", paceSec: 71 }, // 54 questions in 64 minutes
    math: { key: "math", name: "Math", short: "Math", paceSec: 95 }, // 44 questions in 70 minutes
  };
  const BLUEPRINT = [
    { section: "rw", code: "INI", name: "Information and Ideas", weight: 0.26, skills: [["CID", "Central Ideas and Details"], ["INF", "Inferences"], ["COE", "Command of Evidence"]] },
    { section: "rw", code: "CAS", name: "Craft and Structure", weight: 0.28, skills: [["WIC", "Words in Context"], ["TSP", "Text Structure and Purpose"], ["CTC", "Cross-Text Connections"]] },
    { section: "rw", code: "EOI", name: "Expression of Ideas", weight: 0.2, skills: [["SYN", "Rhetorical Synthesis"], ["TRA", "Transitions"]] },
    { section: "rw", code: "SEC", name: "Standard English Conventions", weight: 0.26, skills: [["BOU", "Boundaries"], ["FSS", "Form, Structure, and Sense"]] },
    { section: "math", code: "H", name: "Algebra", weight: 0.35, skills: [["H.A.", "Linear equations in one variable"], ["H.B.", "Linear functions"], ["H.C.", "Linear equations in two variables"], ["H.D.", "Systems of two linear equations in two variables"], ["H.E.", "Linear inequalities in one or two variables"]] },
    { section: "math", code: "P", name: "Advanced Math", weight: 0.325, skills: [["P.A.", "Equivalent expressions"], ["P.B.", "Nonlinear equations in one variable and systems of equations in two variables"], ["P.C.", "Nonlinear functions"]] },
    { section: "math", code: "Q", name: "Problem-Solving and Data Analysis", weight: 0.2, skills: [["Q.A.", "Ratios, rates, proportional relationships, and units"], ["Q.B.", "Percentages"], ["Q.C.", "One-variable data: Distributions and measures of center and spread"], ["Q.D.", "Two-variable data: Models and scatterplots"], ["Q.E.", "Probability and conditional probability"], ["Q.F.", "Inference from sample statistics and margin of error"], ["Q.G.", "Evaluating statistical claims: Observational studies and experiments"]] },
    { section: "math", code: "S", name: "Geometry and Trigonometry", weight: 0.125, skills: [["S.A.", "Area and volume"], ["S.B.", "Lines, angles, and triangles"], ["S.C.", "Right triangles and trigonometry"], ["S.D.", "Circles"]] },
  ];
  const DIFF_NAMES = { E: "Easy", M: "Medium", H: "Hard" };
  const DIFFS = ["E", "M", "H"];
  const LETTERS = "ABCDEFGH".split("");
  const PAGE_SIZE = 25;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  const ESC = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
  const esc = (s) => String(s == null ? "" : s).replace(/[&<>"']/g, (c) => ESC[c]);
  const norm = (s) => String(s || "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
  const pct = (x) => Math.round(x * 100) + "%";
  const plural = (n, word, many) => n + " " + (n === 1 ? word : many || word + "s");
  const view = document.getElementById("view");

  function fmtClock(sec) {
    const s = Math.max(0, Math.round(sec));
    return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
  }
  function dayKey(ms) {
    const d = new Date(ms);
    return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
  }
  function shuffle(arr, rnd) {
    const a = arr.slice();
    const r = rnd || Math.random;
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(r() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }
  function mulberry32(seed) {
    return function () {
      seed |= 0;
      seed = (seed + 0x6d2b79f5) | 0;
      let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  const textTpl = document.createElement("template");
  function plainText(html) {
    textTpl.innerHTML = html || "";
    return (textTpl.content.textContent || "").replace(/\s+/g, " ").trim();
  }

  // ---------------------------------------------------------------------------
  // Question bank and taxonomy
  // ---------------------------------------------------------------------------
  const BANK_LOADED = Array.isArray(window.PSAT_BANK) && window.PSAT_BANK.length > 0;
  const BANK_INFO = window.PSAT_BANK_INFO || null;
  const QUESTIONS = [];
  const QBYID = new Map();
  for (const q of BANK_LOADED ? window.PSAT_BANK : window.PSAT_SAMPLE || []) {
    if (!q || !q.id || !SECTIONS[q.section] || QBYID.has(q.id)) continue;
    if (q.type !== "spr" && !(q.choices && q.choices.length)) continue;
    if (!q.answer || !q.answer.length) continue;
    QUESTIONS.push(q);
    QBYID.set(q.id, q);
  }

  const DOMAINS = [];
  const SKILLS = new Map();
  function addDomain(section, code, name, weight) {
    const d = { key: section + ":" + (code || norm(name)), section, code: code || "", name, weight, skills: [] };
    DOMAINS.push(d);
    return d;
  }
  function addSkill(dom, code, name) {
    const s = { key: dom.section + ":" + norm(name), section: dom.section, domain: dom, code: code || "", name, qids: [], weight: 0 };
    dom.skills.push(s);
    SKILLS.set(s.key, s);
    return s;
  }
  for (const b of BLUEPRINT) {
    const d = addDomain(b.section, b.code, b.name, b.weight);
    for (const [code, name] of b.skills) addSkill(d, code, name);
  }
  for (const q of QUESTIONS) {
    let dom = DOMAINS.find((d) => d.section === q.section && ((q.domainCode && d.code === q.domainCode) || norm(d.name) === norm(q.domain)));
    if (!dom) dom = addDomain(q.section, q.domainCode, q.domain || "Other", 0.1);
    let sk = dom.skills.find((s) => norm(s.name) === norm(q.skill)) || (q.skillCode ? dom.skills.find((s) => s.code === q.skillCode) : null);
    if (!sk) sk = addSkill(dom, q.skillCode, q.skill || "Other");
    q._dom = dom;
    q._skill = sk;
    sk.qids.push(q.id);
  }
  // With the real bank loaded, drop SAT-only skills the PSAT bank doesn't cover
  // (it has no Circles questions, for example).
  if (BANK_LOADED) {
    for (const d of DOMAINS) {
      d.skills = d.skills.filter((s) => {
        if (!s.qids.length) SKILLS.delete(s.key);
        return s.qids.length > 0;
      });
    }
  }
  for (const d of DOMAINS) for (const s of d.skills) s.weight = d.weight / Math.max(1, d.skills.length);
  const skillsOf = (section) => [...SKILLS.values()].filter((s) => !section || s.section === section);

  // ---------------------------------------------------------------------------
  // Saved progress. Always cached in this browser; inside a claude.ai artifact
  // it also syncs to the viewer's private storage so it follows them around.
  // ---------------------------------------------------------------------------
  const LS_KEY = "psat-prep:v1";
  const state = { attempts: [], marked: {}, prefs: {} };
  const validAttempt = (a) => a && typeof a.q === "string" && (a.ok === 0 || a.ok === 1) && typeof a.at === "number";

  function loadLocal() {
    try {
      const raw = localStorage.getItem(LS_KEY);
      if (!raw) return;
      const s = JSON.parse(raw);
      if (Array.isArray(s.attempts)) state.attempts = s.attempts.filter(validAttempt);
      if (s.marked && typeof s.marked === "object") state.marked = s.marked;
      if (s.prefs && typeof s.prefs === "object") state.prefs = s.prefs;
    } catch (e) {
      /* storage blocked: run without it */
    }
  }
  function saveLocal() {
    try {
      localStorage.setItem(LS_KEY, JSON.stringify(state));
    } catch (e) {
      /* storage blocked or full */
    }
  }
  function persist() {
    saveLocal();
    cloudSchedule();
  }
  function setPref(key, value) {
    state.prefs[key] = value;
    saveLocal();
  }

  const CHUNK = 2000;
  const cloud = { on: false, col: null, timer: null, chain: Promise.resolve(), written: {}, retried: false };
  const pack = (a) => [a.q, a.ok, a.at, a.s || 0, a.a || ""];
  const unpack = (r) => (Array.isArray(r) ? { q: String(r[0]), ok: r[1] ? 1 : 0, at: +r[2], s: +r[3] || 0, a: String(r[4] || "") } : null);
  function signature(list) {
    let h = list.length;
    for (const a of list) h = (h * 31 + (a.at % 1000003) + a.ok) % 2147483647;
    return String(h);
  }
  function setSync(mode) {
    const el = document.getElementById("sync-status");
    if (!el) return;
    el.hidden = false;
    el.dataset.state = mode;
    el.textContent = mode === "cloud" ? "Synced to your account" : "Saved in this browser";
  }
  async function initCloud() {
    const c = window.claude;
    if (!c || typeof c.use !== "function") return;
    try {
      const [db, user] = await Promise.all([c.use("db"), c.use("user")]);
      if (!db || !user || typeof user.id !== "function") return;
      const uid = await user.id();
      if (!uid) return;
      const col = db.collection("data/users/" + uid);
      const snap = await col.get();
      const remote = [];
      let remoteMarked = {};
      const docs = snap.docs.filter((d) => d.exists);
      docs
        .filter((d) => /^att-\d+$/.test(d.id))
        .sort((a, b) => +a.id.slice(4) - +b.id.slice(4))
        .forEach((d) => {
          const list = ((d.data() || {}).list || []).map(unpack).filter(validAttempt);
          cloud.written[d.id] = signature(list);
          remote.push(...list);
        });
      const meta = docs.find((d) => d.id === "meta");
      if (meta) {
        remoteMarked = (meta.data() || {}).marked || {};
        cloud.written.meta = JSON.stringify(remoteMarked);
      }
      const seen = new Set();
      const merged = [];
      for (const a of remote.concat(state.attempts)) {
        const k = a.q + "@" + a.at;
        if (!seen.has(k)) {
          seen.add(k);
          merged.push(a);
        }
      }
      merged.sort((a, b) => a.at - b.at);
      state.attempts = merged;
      state.marked = Object.assign({}, remoteMarked, state.marked);
      cloud.col = col;
      cloud.on = true;
      invalidate();
      saveLocal();
      setSync("cloud");
      cloudSchedule(0);
      if (route() !== "session") render();
    } catch (e) {
      setSync("local");
    }
  }
  function cloudSchedule(delay) {
    if (!cloud.on) return;
    clearTimeout(cloud.timer);
    cloud.timer = setTimeout(() => {
      cloud.chain = cloud.chain.then(cloudPush).catch(cloudFail);
    }, delay == null ? 1200 : delay);
  }
  async function cloudPush() {
    if (!cloud.on) return;
    const n = Math.max(1, Math.ceil(state.attempts.length / CHUNK));
    for (let i = 0; i < n; i++) {
      const list = state.attempts.slice(i * CHUNK, (i + 1) * CHUNK);
      const id = "att-" + i;
      const sig = signature(list);
      if (cloud.written[id] === sig) continue;
      await cloud.col.doc(id).set({ list: list.map(pack) });
      cloud.written[id] = sig;
    }
    for (const id of Object.keys(cloud.written)) {
      if (/^att-\d+$/.test(id) && +id.slice(4) >= n) {
        await cloud.col.doc(id).delete();
        delete cloud.written[id];
      }
    }
    const msig = JSON.stringify(state.marked);
    if (cloud.written.meta !== msig) {
      await cloud.col.doc("meta").set({ marked: state.marked });
      cloud.written.meta = msig;
    }
  }
  function cloudFail(e) {
    if (e && e.code === "unavailable" && !cloud.retried) {
      cloud.retried = true;
      cloudSchedule(3000 + Math.random() * 2000);
      return;
    }
    cloud.on = false;
    setSync("local");
  }

  // ---------------------------------------------------------------------------
  // Analytics
  // ---------------------------------------------------------------------------
  function blank() {
    return { n: 0, ok: 0, time: 0, timed: 0, seq: [], diff: { E: { n: 0, ok: 0 }, M: { n: 0, ok: 0 }, H: { n: 0, ok: 0 } }, mastery: 0 };
  }
  function addTo(st, a, q) {
    st.n++;
    st.ok += a.ok;
    if (a.s > 0) {
      st.time += Math.min(a.s, 600);
      st.timed++;
    }
    st.seq.push(a.ok);
    const d = st.diff[q.difficulty];
    if (d) {
      d.n++;
      d.ok += a.ok;
    }
  }
  // Mastery estimate: recency-weighted accuracy (each older answer counts 15%
  // less), pulled toward 50% so two or three answers can't swing it to 0 or 100.
  function mastery(seq) {
    let w = 1;
    let num = 0;
    let den = 0;
    for (let i = seq.length - 1; i >= 0; i--) {
      num += w * seq[i];
      den += w;
      w *= 0.85;
    }
    return (num + 0.5) / (den + 1);
  }
  function computeStats(attempts) {
    const skill = new Map();
    const domain = new Map();
    const perQ = new Map();
    const days = new Map();
    const section = { rw: blank(), math: blank() };
    const overall = blank();
    const getOr = (m, k) => {
      let v = m.get(k);
      if (!v) m.set(k, (v = blank()));
      return v;
    };
    for (const a of attempts) {
      const q = QBYID.get(a.q);
      if (!q) continue;
      addTo(overall, a, q);
      addTo(section[q.section], a, q);
      addTo(getOr(skill, q._skill.key), a, q);
      addTo(getOr(domain, q._dom.key), a, q);
      const p = perQ.get(a.q) || { n: 0, ok: 0, lastOk: 0, lastAt: 0, lastAnswer: "" };
      p.n++;
      p.ok += a.ok;
      p.lastOk = a.ok;
      p.lastAt = a.at;
      p.lastAnswer = a.a || "";
      perQ.set(a.q, p);
      const dk = dayKey(a.at);
      const dv = days.get(dk) || { n: 0, ok: 0 };
      dv.n++;
      dv.ok += a.ok;
      days.set(dk, dv);
    }
    for (const st of skill.values()) st.mastery = mastery(st.seq);
    for (const st of domain.values()) st.mastery = mastery(st.seq);
    return { skill, domain, perQ, days, section, overall };
  }
  let realCache = null;
  let demoCache = null;
  const invalidate = () => (realCache = null);
  const realStats = () => realCache || (realCache = computeStats(state.attempts));
  const isDemo = () => state.attempts.length === 0 && !state.prefs.hideDemo && QUESTIONS.length > 0;
  const dashStats = () => (isDemo() ? demoCache || (demoCache = computeStats(makeDemoAttempts())) : realStats());

  function levelOf(st) {
    if (!st || !st.n) return { key: "none", label: "Not started" };
    if (st.n < 3) return { key: "early", label: "Just started" };
    if (st.mastery >= 0.8) return { key: "strong", label: "Strong" };
    if (st.mastery >= 0.6) return { key: "mid", label: "Getting there" };
    return { key: "weak", label: "Needs work" };
  }
  // Skills ranked by how many points they are likely costing you: low mastery
  // in a heavily tested domain ranks first.
  function focusList(stats, section) {
    const out = [];
    for (const sk of skillsOf(section)) {
      if (!sk.qids.length) continue;
      const st = stats.skill.get(sk.key);
      if (!st || st.n < 2 || st.mastery >= 0.8) continue;
      out.push({ sk, st, priority: (1 - st.mastery) * sk.weight * Math.min(1, st.n / 4) });
    }
    return out.sort((a, b) => b.priority - a.priority);
  }
  function untested(stats, section) {
    return skillsOf(section)
      .filter((sk) => sk.qids.length && !(stats.skill.get(sk.key) || {}).n)
      .sort((a, b) => b.weight - a.weight);
  }
  function insights(stats) {
    const out = [];
    const f = focusList(stats);
    if (f.length) {
      const t = f[0];
      out.push(`Top priority: <b>${esc(t.sk.name)}</b>. You've answered ${t.st.ok} of ${t.st.n} correctly, and ${esc(t.sk.domain.name)} is about ${Math.round(t.sk.domain.weight * 100)}% of the ${SECTIONS[t.sk.section].name} section.`);
    }
    const rw = stats.section.rw;
    const m = stats.section.math;
    if (rw.n >= 5 && m.n >= 5) {
      const ar = rw.ok / rw.n;
      const am = m.ok / m.n;
      if (Math.abs(ar - am) >= 0.1) {
        const weak = ar < am ? "Reading and Writing" : "Math";
        const strong = ar < am ? "Math" : "Reading and Writing";
        out.push(`${weak} is your weaker section: ${pct(Math.min(ar, am))} correct, compared with ${pct(Math.max(ar, am))} in ${strong}.`);
      }
    }
    for (const key of ["rw", "math"]) {
      const s = stats.section[key];
      const e = s.diff.E;
      const h = s.diff.H;
      if (e.n >= 3 && h.n >= 3 && e.ok / e.n - h.ok / h.n >= 0.3) {
        out.push(`In ${SECTIONS[key].name}, you get ${pct(e.ok / e.n)} of Easy questions right but ${pct(h.ok / h.n)} of Hard ones. Add more Hard questions to your practice sets.`);
      }
    }
    for (const key of ["rw", "math"]) {
      const s = stats.section[key];
      if (s.timed >= 5) {
        const avg = s.time / s.timed;
        const pace = SECTIONS[key].paceSec;
        if (avg > pace * 1.15) out.push(`You spend about ${Math.round(avg)} seconds per ${SECTIONS[key].name} question. Test pace is about ${pace} seconds, so practice some timed sets.`);
      }
    }
    for (const key of ["rw", "math"]) {
      const all = skillsOf(key).filter((s) => s.qids.length);
      const u = untested(stats, key);
      if (u.length && u.length < all.length) out.push(`You haven't tried ${u.length} of the ${all.length} ${SECTIONS[key].name} skills yet, including ${esc(u[0].name)}.`);
    }
    let best = null;
    for (const sk of SKILLS.values()) {
      const st = stats.skill.get(sk.key);
      if (st && st.n >= 3 && st.mastery >= 0.8 && (!best || st.mastery > best.st.mastery)) best = { sk, st };
    }
    if (best) out.push(`Strongest skill: <b>${esc(best.sk.name)}</b>, with ${best.st.ok} of ${best.st.n} correct.`);
    return out.slice(0, 5);
  }

  // Example progress for the first visit, so the dashboard shows what it does.
  // Never saved and never mixed with real answers.
  function makeDemoAttempts() {
    const rnd = mulberry32(20261003);
    const pool = [...SKILLS.values()].filter((s) => s.qids.length);
    const target = new Map(pool.map((s) => [s.key, 0.3 + rnd() * 0.62]));
    const out = [];
    const today = new Date();
    today.setHours(17, 0, 0, 0);
    for (let d = 13; d >= 0; d--) {
      if (d !== 0 && rnd() < 0.25) continue;
      const count = 5 + Math.floor(rnd() * 12);
      for (let i = 0; i < count; i++) {
        const sk = pool[Math.floor(rnd() * pool.length)];
        const q = QBYID.get(sk.qids[Math.floor(rnd() * sk.qids.length)]);
        const chance = target.get(sk.key) + (13 - d) * 0.012 + ({ E: 0.15, M: 0, H: -0.2 }[q.difficulty] || 0);
        out.push({
          q: q.id,
          ok: rnd() < Math.min(0.96, chance) ? 1 : 0,
          at: today.getTime() - d * 864e5 - (count - i) * 150e3,
          s: Math.round(SECTIONS[q.section].paceSec * (0.6 + rnd() * 0.95)),
          a: "",
        });
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Building practice sets
  // ---------------------------------------------------------------------------
  // Unseen questions first, then ones you missed last time, then the rest.
  function pickQuestions(pool, count, preferDiffs) {
    const perQ = realStats().perQ;
    const rank = (q) => {
      const p = perQ.get(q.id);
      const seen = !p ? 0 : p.lastOk ? 2 : 1;
      const diffPenalty = preferDiffs && !preferDiffs.includes(q.difficulty) ? 3 : 0;
      return seen + diffPenalty;
    };
    const buckets = new Map();
    for (const q of pool) {
      const r = rank(q);
      if (!buckets.has(r)) buckets.set(r, []);
      buckets.get(r).push(q);
    }
    return [...buckets.keys()]
      .sort((a, b) => a - b)
      .flatMap((k) => shuffle(buckets.get(k)))
      .slice(0, count);
  }
  const questionsOf = (sk) => sk.qids.map((id) => QBYID.get(id));
  const diffsFor = (m) => (m == null ? ["M"] : m < 0.5 ? ["E", "M"] : m < 0.75 ? ["M", "H"] : ["H"]);

  function skillSet(sk, count) {
    const st = realStats().skill.get(sk.key);
    return pickQuestions(questionsOf(sk), count, diffsFor(st && st.n ? st.mastery : null)).map((q) => q.id);
  }
  // No history yet: spread questions across skills in proportion to how
  // heavily each is tested, favoring Medium difficulty.
  function diagnosticSet(section, count) {
    const skills = skillsOf(section).filter((s) => s.qids.length);
    const totalW = skills.reduce((s, k) => s + k.weight, 0) || 1;
    const alloc = skills.map((sk) => ({ sk, exact: (count * sk.weight) / totalW }));
    alloc.forEach((a) => (a.n = Math.floor(a.exact)));
    let left = count - alloc.reduce((s, a) => s + a.n, 0);
    alloc.slice().sort((a, b) => b.exact - b.n - (a.exact - a.n)).forEach((a) => {
      if (left > 0) {
        a.n++;
        left--;
      }
    });
    const ids = [];
    for (const a of alloc) if (a.n) ids.push(...pickQuestions(questionsOf(a.sk), a.n, ["M"]).map((q) => q.id));
    return shuffle(ids);
  }
  function smartSet(section, count) {
    const stats = realStats();
    const focus = focusList(stats, section).slice(0, 3);
    if (!focus.length) return { ids: diagnosticSet(section, count), label: "Diagnostic mix" };
    const fresh = untested(stats, section);
    const freshN = fresh.length ? Math.max(1, Math.round(count * 0.2)) : 0;
    const focusN = count - freshN;
    const total = focus.reduce((s, f) => s + f.priority, 0) || 1;
    const ids = [];
    let used = 0;
    focus.forEach((f, i) => {
      const n = Math.max(0, i === focus.length - 1 ? focusN - used : Math.min(focusN - used, Math.max(1, Math.round((focusN * f.priority) / total))));
      used += n;
      ids.push(...pickQuestions(questionsOf(f.sk), n, diffsFor(f.st.mastery)).map((q) => q.id));
    });
    if (freshN) ids.push(...pickQuestions(questionsOf(fresh[0]), freshN, ["M"]).map((q) => q.id));
    if (ids.length < count) {
      const have = new Set(ids);
      const extra = QUESTIONS.filter((q) => !have.has(q.id) && (!section || q.section === section));
      ids.push(...pickQuestions(extra, count - ids.length).map((q) => q.id));
    }
    return { ids: shuffle(ids), label: "Smart practice: " + focus.map((f) => f.sk.name).join(", ") };
  }

  function customDefaults() {
    return Object.assign({ section: "rw", exclude: {}, diff: { E: true, M: true, H: true }, from: "all", count: 10, feedback: "each", timer: "off" }, state.prefs.custom || {});
  }
  function customPool(c) {
    const perQ = realStats().perQ;
    return QUESTIONS.filter((q) => {
      if (c.section !== "both" && q.section !== c.section) return false;
      if (c.exclude[q._skill.key]) return false;
      if (!c.diff[q.difficulty]) return false;
      const p = perQ.get(q.id);
      if (c.from === "new" && p) return false;
      if (c.from === "missed" && !(p && !p.lastOk)) return false;
      if (c.from === "marked" && !state.marked[q.id]) return false;
      return true;
    });
  }

  // ---------------------------------------------------------------------------
  // Answer checking
  // ---------------------------------------------------------------------------
  const cleanAns = (x) => String(x == null ? "" : x).trim().replace(/[−–]/g, "-").replace(/\s+/g, "").replace(/^\+/, "").toLowerCase();
  function parseNum(s) {
    if (/^-?\d*\.?\d+$/.test(s)) return parseFloat(s);
    const m = s.match(/^(-?\d*\.?\d+)\/(-?\d*\.?\d+)$/);
    if (m) {
      const d = parseFloat(m[2]);
      return d ? parseFloat(m[1]) / d : NaN;
    }
    return NaN;
  }
  const close = (a, b) => Math.abs(a - b) <= 1e-9 * Math.max(1, Math.abs(a), Math.abs(b));
  function sprAccepted(q) {
    return q.answer.flatMap((a) => String(a).split(/,|\bor\b/)).map(cleanAns).filter(Boolean);
  }
  // Student-produced responses follow the digital PSAT's rules: fractions and
  // decimals are both fine, and a decimal that fills every space (5 characters,
  // 6 with a minus sign) may be truncated or rounded.
  function checkSpr(q, input) {
    const given = cleanAns(input);
    if (!given) return false;
    const accepted = sprAccepted(q);
    if (accepted.includes(given)) return true;
    const g = parseNum(given);
    if (!isFinite(g)) return false;
    const values = accepted.map(parseNum).filter(isFinite);
    if (values.some((v) => close(v, g))) return true;
    const full = given.length >= (g < 0 ? 6 : 5) && given.includes(".") && !given.includes("/");
    if (full) {
      const places = given.split(".")[1].length;
      const f = Math.pow(10, places);
      return values.some((v) => close(Math.trunc(v * f) / f, g) || close(Math.round(v * f) / f, g));
    }
    return false;
  }
  const correctLetter = (q) => String(q.answer[0]).trim().toUpperCase();
  function isCorrect(q, given) {
    return q.type === "spr" ? checkSpr(q, given) : String(given || "").toUpperCase() === correctLetter(q);
  }
  function answerLabel(q) {
    if (q.type !== "spr") return correctLetter(q);
    const list = [...new Set(q.answer.flatMap((a) => String(a).split(",")).map((s) => s.trim()).filter(Boolean))];
    return list.join(" or ");
  }

  // ---------------------------------------------------------------------------
  // Session state (in memory; survives an artifact republish via hot data)
  // ---------------------------------------------------------------------------
  let session = null;
  let lastSummary = null;
  let viewer = null;
  let timerId = null;
  let bankPage = 0;
  let resetArmed = false;

  function startSession(ids, opts) {
    ids = ids.filter((id) => QBYID.has(id));
    if (!ids.length) return;
    const o = opts || {};
    const limit = o.timed ? ids.reduce((s, id) => s + SECTIONS[QBYID.get(id).section].paceSec, 0) : 0;
    session = { ids, idx: 0, label: o.label || "Practice", feedback: o.feedback || "each", timed: !!o.timed, limit, startedAt: Date.now(), shownAt: Date.now(), sel: null, spr: "", elim: {}, results: {}, timeUp: false };
    go("session");
  }
  function finishSession() {
    if (!session) return;
    const s = session;
    const items = s.ids.map((id) => ({ id, r: s.results[id] || null }));
    lastSummary = { label: s.label, items, startedAt: s.startedAt, endedAt: Date.now(), timeUp: s.timeUp, timed: s.timed, limit: s.limit };
    session = null;
    go("summary");
  }
  function recordAttempt(q, ok, given, secs) {
    state.attempts.push({ q: q.id, ok: ok ? 1 : 0, at: Date.now(), s: Math.min(1800, Math.round(secs)), a: String(given == null ? "" : given).slice(0, 12) });
    invalidate();
    persist();
  }

  // ---------------------------------------------------------------------------
  // Router
  // ---------------------------------------------------------------------------
  const ROUTES = ["dashboard", "practice", "bank", "review", "session", "summary", "question"];
  const TAB_FOR = { session: "practice", summary: "practice" };
  function route() {
    const h = location.hash.replace(/^#/, "");
    return ROUTES.includes(h) ? h : "dashboard";
  }
  function go(r) {
    if (location.hash !== "#" + r) location.hash = r;
    else render();
  }
  function render() {
    let r = route();
    if (r === "session" && !session) r = "practice";
    if (r === "summary" && !lastSummary) r = "practice";
    if (r === "question" && !viewer) r = "review";
    const tab = r === "question" ? viewer.from : TAB_FOR[r] || r;
    document.querySelectorAll(".tabs a").forEach((a) => {
      if (a.dataset.route === tab) a.setAttribute("aria-current", "page");
      else a.removeAttribute("aria-current");
    });
    if (r !== "session") stopTimer();
    view.innerHTML = VIEWS[r]();
    if (r === "session") startTimer();
    if (r === "dashboard") wireChart();
    renderFooter();
  }
  function scrollTop() {
    window.scrollTo(0, 0);
  }

  // ---------------------------------------------------------------------------
  // Shared fragments
  // ---------------------------------------------------------------------------
  function diffChip(d) {
    const n = DIFFS.indexOf(d) + 1;
    return `<span class="chip diff" title="Difficulty"><span class="diff-pips" aria-hidden="true">${[1, 2, 3].map((i) => `<i class="${i <= n ? "on" : ""}"></i>`).join("")}</span>${esc(DIFF_NAMES[d] || d || "Unrated")}</span>`;
  }
  function levelChip(st) {
    const l = levelOf(st);
    return `<span class="chip lvl-${l.key}"><span class="dot" aria-hidden="true"></span>${l.label}</span>`;
  }
  function meter(st) {
    const l = levelOf(st);
    const w = st && st.n ? Math.round(st.mastery * 100) : 0;
    return `<span class="meter"><span class="track"><span class="fill lvl-${l.key}" style="width:${w}%"></span></span><span class="pct">${st && st.n ? w + "%" : "–"}</span></span>`;
  }
  function sampleBanner() {
    if (BANK_LOADED) return "";
    return `<div class="banner"><p><b>Sample mode.</b> The full College Board PSAT question bank isn't loaded yet, so you're practicing with ${QUESTIONS.length} original sample questions. Run <code>node scripts/fetch-questions.mjs</code> in the <code>psat-prep</code> folder to download every question and explanation.</p></div>`;
  }
  function statusChips(id) {
    const p = realStats().perQ.get(id);
    let html = "";
    if (p) html += p.lastOk ? `<span class="chip ok">✓ Correct</span>` : `<span class="chip bad">✗ Missed</span>`;
    if (state.marked[id]) html += `<span class="chip flag">⚑ Marked</span>`;
    return html || `<span class="chip">Not tried</span>`;
  }
  function snippet(q) {
    if (q._snip == null) {
      const src = q.section === "rw" ? q.stimulus || q.stem : (q.stimulus ? q.stimulus + " " : "") + q.stem;
      const t = plainText(src);
      q._snip = t.length > 180 ? t.slice(0, 177) + "…" : t;
    }
    return q._snip;
  }
  function qRow(q, extra) {
    return `<li><button class="qrow" data-action="open-q" data-id="${esc(q.id)}">
      <span class="snippet">${esc(snippet(q))}</span>
      <span class="tags"><span>${esc(SECTIONS[q.section].short)}</span>·<span>${esc(q._skill.name)}</span>·<span>${esc(DIFF_NAMES[q.difficulty] || "")}</span>${extra ? "·" + extra : ""}</span>
      <span class="status">${statusChips(q.id)}</span>
    </button></li>`;
  }
  function seg(name, options, current) {
    return `<div class="seg" role="group">${options
      .map(([v, label]) => `<button type="button" data-action="seg" data-name="${esc(name)}" data-value="${esc(v)}" aria-pressed="${String(v) === String(current)}">${esc(label)}</button>`)
      .join("")}</div>`;
  }

  // ---------------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------------
  function viewDashboard() {
    const demo = isDemo();
    const stats = dashStats();
    const o = stats.overall;
    let html = `<div class="page-head"><div><h1>Your PSAT dashboard</h1><p class="lede">${
      o.n ? `Based on ${plural(o.n, "answer")}${demo ? " of example data" : ""}. Skill bars show a mastery estimate where recent answers count more than old ones.` : "Answer some questions and this page shows which PSAT skills need the most work."
    }</p></div><div class="btn-row"><button class="btn" data-action="smart" data-section="" data-count="10">${o.n && !demo ? "Start smart practice" : "Take a 10-question diagnostic"}</button></div></div>`;
    html += sampleBanner();
    if (demo) {
      html += `<div class="banner info"><p><b>Example data.</b> This is what the dashboard looks like after two weeks of practice. Answer your first question and it switches to your own results.</p><button class="btn btn-secondary btn-sm" data-action="hide-demo">Hide example</button></div>`;
    }
    if (!o.n) {
      html += `<div class="panel"><div class="empty"><h2>No answers yet</h2><p>Start with a short diagnostic. It spreads questions across every skill, weighted like the real test.</p><div class="btn-row"><button class="btn" data-action="smart" data-section="" data-count="10">Take a 10-question diagnostic</button>${
        state.attempts.length === 0 ? `<button class="btn btn-secondary" data-action="show-demo">Preview with example data</button>` : ""
      }</div></div></div>`;
      return html;
    }

    const acc = (s) => (s.n ? pct(s.ok / s.n) : "–");
    const avgT = o.timed ? Math.round(o.time / o.timed) : 0;
    html += `<div class="stat-row">
      <div class="stat"><span class="label">Questions answered</span><span class="value num">${o.n}</span><span class="sub">${plural(stats.perQ.size, "different question")}</span></div>
      <div class="stat"><span class="label">Overall accuracy</span><span class="value num">${acc(o)}</span><span class="sub">${o.ok} correct</span></div>
      <div class="stat"><span class="label">Reading and Writing</span><span class="value num">${acc(stats.section.rw)}</span><span class="sub">${plural(stats.section.rw.n, "answer")}</span></div>
      <div class="stat"><span class="label">Math</span><span class="value num">${acc(stats.section.math)}</span><span class="sub">${plural(stats.section.math.n, "answer")}</span></div>
      <div class="stat"><span class="label">Time per question</span><span class="value num">${avgT ? avgT + "<small> s</small>" : "–"}</span><span class="sub">Test pace: 71 s R&amp;W, 95 s Math</span></div>
    </div>`;

    const focus = focusList(stats).slice(0, 5);
    const fresh = untested(stats);
    let focusHtml;
    if (focus.length) {
      focusHtml = `<ol class="focus-list">${focus
        .map(
          (f, i) => `<li class="focus-item">
          <span class="focus-rank num" aria-hidden="true">${i + 1}</span>
          <span class="focus-name">${esc(f.sk.name)}</span>
          <span class="focus-meta">${levelChip(f.st)}<span class="num">${f.st.ok}/${f.st.n} correct</span><span>${esc(f.sk.domain.name)} · ~${Math.round(f.sk.domain.weight * 100)}% of ${esc(SECTIONS[f.sk.section].short)}</span></span>
          <button class="btn btn-secondary btn-sm" data-action="practice-skill" data-skill="${esc(f.sk.key)}">Practice</button>
        </li>`
        )
        .join("")}</ol>`;
    } else {
      focusHtml = `<p class="muted">Nothing below 80% mastery with at least two answers. ${fresh.length ? "Try a skill you haven't practiced yet." : "Keep mixing in Hard questions."}</p>`;
    }
    const ins = insights(stats);
    const left = `<div class="dash-col">
      <section class="panel"><div class="panel-head"><h2>Work on these next</h2><p>Ranked by mastery and how much of the test each skill covers</p></div>${focusHtml}</section>
      ${ins.length ? `<section class="panel"><h2>What your answers show</h2><ul class="insights">${ins.map((t) => `<li><span>${t}</span></li>`).join("")}</ul></section>` : ""}
      ${
        fresh.length
          ? `<section class="panel"><div class="panel-head"><h2>Not tried yet</h2><p>${plural(fresh.length, "skill")}</p></div><div class="btn-row">${fresh
              .slice(0, 12)
              .map((sk) => `<button class="btn btn-secondary btn-sm" data-action="practice-skill" data-skill="${esc(sk.key)}">${esc(sk.name)}</button>`)
              .join("")}</div></section>`
          : ""
      }
      <section class="panel"><div class="panel-head"><h2>Last 14 days</h2></div>${activityChart(stats)}</section>
    </div>`;

    const right = `<div class="dash-col">
      <section class="panel"><div class="panel-head"><h2>Skill map</h2><p>Select a skill to practice it</p></div>${skillMap(stats)}</section>
      <section class="panel"><h2>Accuracy by difficulty</h2><div class="subgrid">${["rw", "math"]
        .map(
          (k) => `<div><h3>${SECTIONS[k].name}</h3><div class="hbar-list">${DIFFS.map((d) => {
            const v = stats.section[k].diff[d];
            const a = v.n ? v.ok / v.n : 0;
            return `<div class="hbar"><span class="lab">${DIFF_NAMES[d]}</span><span class="track"><span class="fill" style="width:${Math.round(a * 100)}%"></span></span><span class="val">${v.n ? `${pct(a)} · ${v.ok}/${v.n}` : "no answers"}</span></div>`;
          }).join("")}</div></div>`
        )
        .join("")}</div></section>
      <section class="panel"><div class="panel-head"><h2>Pacing</h2><p>Line marks test pace</p></div><div class="hbar-list">${["rw", "math"]
        .map((k) => {
          const s = stats.section[k];
          const pace = SECTIONS[k].paceSec;
          const avg = s.timed ? s.time / s.timed : 0;
          const scale = pace * 2;
          return `<div class="hbar"><span class="lab">${SECTIONS[k].short}</span><span class="track"><span class="fill" style="width:${Math.min(100, (avg / scale) * 100).toFixed(1)}%"></span><span class="marker" style="left:50%" title="Test pace ${pace} s"></span></span><span class="val">${avg ? `${Math.round(avg)} s / ${pace} s` : "no answers"}</span></div>`;
        })
        .join("")}</div></section>
    </div>`;
    html += `<div class="dash-grid">${left}${right}</div>`;
    return html;
  }

  function skillMap(stats) {
    return ["rw", "math"]
      .map((sec) => {
        const ss = stats.section[sec];
        return `<div class="skill-section"><h3><span>${SECTIONS[sec].name}</span><span class="muted small num">${ss.n ? `${pct(ss.ok / ss.n)} of ${ss.n}` : "no answers yet"}</span></h3>${DOMAINS.filter((d) => d.section === sec)
          .map((d) => {
            const ds = stats.domain.get(d.key);
            return `<div class="domain"><div class="domain-head"><strong>${esc(d.name)}</strong><span>~${Math.round(d.weight * 100)}% of section${ds && ds.n ? ` · ${ds.ok}/${ds.n} correct` : ""}</span></div>${d.skills
              .map((sk) => {
                const st = stats.skill.get(sk.key);
                const has = sk.qids.length > 0;
                return `<button class="skill-row" data-action="practice-skill" data-skill="${esc(sk.key)}" ${has ? "" : "disabled"} title="${has ? "Practice " + esc(sk.name) : "No questions loaded for this skill"}">
                  <span class="name">${esc(sk.name)}<span class="num">${st && st.n ? `${st.ok}/${st.n} correct` : has ? plural(sk.qids.length, "question") : "No questions loaded"}</span></span>
                  ${meter(st)}
                  ${levelChip(st)}
                </button>`;
              })
              .join("")}</div>`;
          })
          .join("")}</div>`;
      })
      .join("");
  }

  function activityChart(stats) {
    const days = [];
    const base = new Date();
    base.setHours(0, 0, 0, 0);
    for (let i = 13; i >= 0; i--) {
      const d = new Date(base);
      d.setDate(base.getDate() - i);
      const v = stats.days.get(dayKey(d.getTime())) || { n: 0, ok: 0 };
      days.push({ d, n: v.n, ok: v.ok, today: i === 0 });
    }
    const peak = Math.max(4, ...days.map((x) => x.n));
    const step = peak <= 10 ? 2 : peak <= 20 ? 5 : peak <= 50 ? 10 : 25;
    const max = Math.ceil(peak / step) * step;
    const W = 640;
    const H = 210;
    const L = 30;
    const R = 6;
    const T = 10;
    const B = 26;
    const y = (v) => T + (H - T - B) * (1 - v / max);
    const band = (W - L - R) / days.length;
    const bw = Math.min(26, band * 0.6);
    const topRounded = (x, yTop, w, h, r) => {
      r = Math.min(r, h, w / 2);
      return `M${x},${yTop + h}V${yTop + r}Q${x},${yTop} ${x + r},${yTop}H${x + w - r}Q${x + w},${yTop} ${x + w},${yTop + r}V${yTop + h}Z`;
    };
    let g = "";
    for (let v = 0; v <= max; v += step) {
      g += `<line class="${v === 0 ? "baseline" : "gridline"}" x1="${L}" x2="${W - R}" y1="${y(v)}" y2="${y(v)}"/><text class="axis-label" x="${L - 6}" y="${y(v) + 4}" text-anchor="end">${v}</text>`;
    }
    days.forEach((dd, i) => {
      const cx = L + band * i + band / 2;
      const x = cx - bw / 2;
      const miss = dd.n - dd.ok;
      if (dd.ok > 0) {
        const top = y(dd.ok);
        const h = y(0) - top;
        g += miss > 0 ? `<rect class="seg-correct" x="${x}" y="${top}" width="${bw}" height="${h}"/>` : `<path class="seg-correct" d="${topRounded(x, top, bw, h, 4)}"/>`;
      }
      if (miss > 0) {
        const top = y(dd.n);
        const bottom = dd.ok > 0 ? y(dd.ok) - 2 : y(0);
        if (bottom - top > 0.5) g += `<path class="seg-missed" d="${topRounded(x, top, bw, bottom - top, 4)}"/>`;
      }
      if (i % 2 === 1 || dd.today) {
        const label = dd.today ? "Today" : dd.d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
        if (dd.today || i < days.length - 2) g += `<text class="axis-label" x="${cx}" y="${H - 8}" text-anchor="middle">${esc(label)}</text>`;
      }
      const tip = `${dd.d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" })}|${dd.n ? `${dd.ok} correct · ${miss} missed · ${pct(dd.ok / dd.n)}` : "No practice"}`;
      g += `<rect class="hit" x="${L + band * i}" y="${T}" width="${band}" height="${H - T - B}" data-tip="${esc(tip)}"/>`;
    });
    const total = days.reduce((s, d) => s + d.n, 0);
    const active = days.filter((d) => d.n).length;
    return `<div class="legend" aria-hidden="true"><span><i class="k-correct"></i>Correct</span><span><i class="k-missed"></i>Missed</span><span class="muted">${plural(total, "answer")} on ${plural(active, "day")}</span></div>
      <div class="chart" id="activity-chart"><svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Questions answered per day over the last 14 days, split into correct and missed">${g}</svg><div class="tooltip" hidden></div></div>`;
  }
  function wireChart() {
    const chart = document.getElementById("activity-chart");
    if (!chart) return;
    const tip = chart.querySelector(".tooltip");
    chart.addEventListener("pointerover", (e) => {
      const hit = e.target.closest(".hit");
      if (!hit) return;
      const [title, body] = hit.dataset.tip.split("|");
      tip.innerHTML = `<b>${esc(title)}</b>${esc(body)}`;
      const box = chart.getBoundingClientRect();
      const r = hit.getBoundingClientRect();
      tip.style.left = Math.min(box.width - 70, Math.max(70, r.left - box.left + r.width / 2)) + "px";
      tip.style.top = r.top - box.top + 8 + "px";
      tip.hidden = false;
    });
    chart.addEventListener("pointerleave", () => (tip.hidden = true));
  }

  // ---------------------------------------------------------------------------
  // Practice setup
  // ---------------------------------------------------------------------------
  function viewPractice() {
    const stats = realStats();
    const smartSec = state.prefs.smartSection || "";
    const smartCount = state.prefs.smartCount || 10;
    const focus = focusList(stats, smartSec).slice(0, 3);
    const fresh = untested(stats, smartSec);
    const c = customDefaults();
    let html = `<div class="page-head"><div><h1>Practice</h1><p class="lede">Every question comes with the full explanation. Your answers feed the dashboard.</p></div></div>`;
    html += sampleBanner();
    if (session) {
      html += `<div class="banner info"><p><b>Session in progress:</b> ${esc(session.label)}, question ${session.idx + 1} of ${session.ids.length}.</p><div class="btn-row"><button class="btn btn-sm" data-action="resume">Resume</button><button class="btn btn-secondary btn-sm" data-action="end-session">End it</button></div></div>`;
    }
    html += `<div class="setup-grid">
      <section class="panel smart-card">
        <h2>Smart practice</h2>
        ${
          focus.length
            ? `<p>Built from the skills costing you the most points:</p><ul>${focus.map((f) => `<li>${esc(f.sk.name)} <span class="muted">(${f.st.ok}/${f.st.n} correct)</span></li>`).join("")}${fresh.length ? `<li>Plus one skill you haven't tried: ${esc(fresh[0].name)}</li>` : ""}</ul><p class="muted small">Difficulty adjusts to your level in each skill. Questions you haven't seen come first, then ones you missed.</p>`
            : `<p>You don't have enough answers yet, so this starts as a <b>diagnostic</b>: questions spread across every skill, weighted like the real test.</p>`
        }
        <div class="field"><span class="label">Section</span>${seg("smartSection", [["", "Both"], ["rw", "Reading and Writing"], ["math", "Math"]], smartSec)}</div>
        <div class="field"><span class="label">Questions</span>${seg("smartCount", [[10, "10"], [20, "20"], [30, "30"]], smartCount)}</div>
        <div><button class="btn" data-action="smart" data-section="${esc(smartSec)}" data-count="${smartCount}">Start smart practice</button></div>
      </section>
      <section class="panel">
        <h2>Build your own set</h2>
        <form class="setup-form" id="custom-form" onsubmit="return false">
          <div class="row">
            <div class="field"><span class="label">Section</span>${seg("c.section", [["rw", "Reading and Writing"], ["math", "Math"], ["both", "Both"]], c.section)}</div>
          </div>
          <div class="field"><span class="label">Skills</span><div class="skill-picker">${DOMAINS.filter((d) => c.section === "both" || d.section === c.section)
            .map(
              (d) => `<fieldset><legend>${esc(d.name)} <button type="button" class="btn btn-ghost btn-sm" data-action="toggle-domain" data-domain="${esc(d.key)}">${d.skills.every((s) => !c.exclude[s.key]) ? "None" : "All"}</button></legend>${d.skills
                .map(
                  (sk) => `<label class="check"><input type="checkbox" id="sk-${esc(sk.key.replace(/[^a-z0-9]/gi, "-"))}" data-change="skill" data-skill="${esc(sk.key)}" ${c.exclude[sk.key] ? "" : "checked"} ${sk.qids.length ? "" : "disabled"}><span>${esc(sk.name)} <span class="count">${sk.qids.length}</span></span></label>`
                )
                .join("")}</fieldset>`
            )
            .join("")}</div></div>
          <div class="row">
            <div class="field"><span class="label">Difficulty</span><div class="btn-row">${DIFFS.map((d) => `<label class="check"><input type="checkbox" id="diff-${d}" data-change="diff" data-diff="${d}" ${c.diff[d] ? "checked" : ""}><span>${DIFF_NAMES[d]}</span></label>`).join("")}</div></div>
            <div class="field"><span class="label">Questions from</span>${seg("c.from", [["all", "All"], ["new", "Not tried"], ["missed", "Missed"], ["marked", "Marked"]], c.from)}</div>
          </div>
          <div class="row">
            <div class="field"><span class="label">How many</span>${seg("c.count", [[5, "5"], [10, "10"], [20, "20"], [0, "All"]], c.count)}</div>
            <div class="field"><span class="label">Explanations</span>${seg("c.feedback", [["each", "After each question"], ["end", "At the end"]], c.feedback)}</div>
            <div class="field"><span class="label">Timer</span>${seg("c.timer", [["off", "Off"], ["pace", "Test pace"]], c.timer)}</div>
          </div>
          <div class="btn-row"><button type="button" class="btn" data-action="start-custom" id="start-custom">Start</button><span class="match-count" id="match-count"></span></div>
        </form>
      </section>
    </div>`;
    setTimeout(updateMatchCount, 0);
    return html;
  }
  function updateMatchCount() {
    const el = document.getElementById("match-count");
    if (!el) return;
    const c = customDefaults();
    const n = customPool(c).length;
    const take = c.count ? Math.min(c.count, n) : n;
    el.textContent = n ? `${plural(n, "question")} match. This set will have ${take}.` : "No questions match these filters.";
    const btn = document.getElementById("start-custom");
    if (btn) btn.disabled = !n;
  }

  // ---------------------------------------------------------------------------
  // Question view (used by sessions and by single-question review)
  // ---------------------------------------------------------------------------
  function questionBody(q, o) {
    // o: { locked, sel, spr, elim, result: { ok, given } | null, showAnswer }
    const split = q.section === "rw" && q.stimulus;
    const meta = `<div class="q-meta"><span class="chip">${esc(q._dom.name)}</span><span class="chip">${esc(q._skill.name)}</span>${diffChip(q.difficulty)}<span class="chip num" title="Question ID">ID ${esc(q.id)}</span></div>`;
    let answerArea;
    if (q.type === "spr") {
      const cls = o.showAnswer && o.result ? (o.result.ok ? "is-correct" : "is-wrong") : "";
      answerArea = `<div class="spr ${cls}"><label for="spr-input" class="small"><b>Your answer</b></label><input type="text" id="spr-input" inputmode="decimal" autocomplete="off" spellcheck="false" maxlength="6" value="${esc(o.spr || "")}" ${o.locked ? "disabled" : ""} data-change="spr"><span class="hint" id="spr-preview">${sprPreview(o.spr)}</span></div>`;
    } else {
      const right = correctLetter(q);
      answerArea = `<div class="choices" role="group" aria-label="Answer choices">${q.choices
        .map((html, i) => {
          const L = LETTERS[i];
          const cls = [];
          if (o.sel === L) cls.push("selected");
          if (o.elim && o.elim[L]) cls.push("eliminated");
          if (o.showAnswer) {
            if (L === right) cls.push("is-correct");
            else if (o.result && o.result.given === L) cls.push("is-wrong");
          }
          return `<div class="choice ${cls.join(" ")}" data-letter="${L}"><button type="button" class="choice-btn" data-action="choose" data-letter="${L}" aria-pressed="${o.sel === L}" ${o.locked ? "disabled" : ""}><span class="bubble">${L}</span><span class="choice-text">${html}</span></button><button type="button" class="elim" data-action="eliminate" data-letter="${L}" title="Cross out ${L}" aria-label="Cross out choice ${L}" ${o.locked ? "disabled" : ""}>${L}</button></div>`;
        })
        .join("")}</div>`;
    }
    // R&W passages sit in their own pane, as in Bluebook; Math figures and
    // tables stay above the question.
    const pane = split ? `<section class="q-stimulus reading">${q.stimulus}</section>` : "";
    const inline = !split && q.stimulus ? `<div class="reading">${q.stimulus}</div>` : "";
    return { split, html: `${pane}<section class="q-main">${meta}${inline}<div class="q-stem reading">${q.stem || ""}</div>${answerArea}__ACTIONS__${o.showAnswer ? feedbackHtml(q, o.result) : ""}</section>` };
  }
  function feedbackHtml(q, result) {
    let head;
    if (!result) head = `<div class="feedback-head">Correct answer: ${esc(answerLabel(q))}</div>`;
    else if (result.ok) head = `<div class="feedback-head">✓ Correct${q.type === "spr" ? ": " + esc(answerLabel(q)) : ""}</div>`;
    else head = `<div class="feedback-head">✗ ${result.given ? `You answered ${esc(result.given)}.` : "Not answered."} Correct answer: ${esc(answerLabel(q))}</div>`;
    const cls = !result ? "neutral" : result.ok ? "ok" : "bad";
    return `<div class="feedback ${cls}" id="feedback">${head}<div class="rationale"><div class="eyebrow">Explanation</div><div class="reading">${q.rationale || "<p>No explanation available.</p>"}</div></div></div>`;
  }
  function sprPreview(v) {
    const s = cleanAns(v);
    if (!s) return "Enter a number, decimal, or fraction like 3/4 or -2.5. Don't type units or commas.";
    const m = s.match(/^(-?)(\d*\.?\d+)\/(\d*\.?\d+)$/);
    const shown = m ? `<math>${m[1] ? "<mo>−</mo>" : ""}<mfrac><mn>${esc(m[2])}</mn><mn>${esc(m[3])}</mn></mfrac></math>` : esc(s.replace(/^-/, "−"));
    return `Answer preview: ${shown}`;
  }

  function viewSession() {
    const s = session;
    const q = QBYID.get(s.ids[s.idx]);
    const r = s.results[q.id] || null;
    const answered = !!r;
    const showAnswer = answered && s.feedback === "each";
    const body = questionBody(q, { locked: answered, sel: r ? r.given : s.sel, spr: r ? r.given : s.spr, elim: s.elim, result: r, showAnswer });
    const last = s.idx === s.ids.length - 1;
    let actions;
    if (!answered) {
      const canCheck = q.type === "spr" ? !!cleanAns(s.spr) : !!s.sel;
      actions = `<div class="q-actions"><button class="btn" data-action="check" id="check-btn" ${canCheck ? "" : "disabled"}>${s.feedback === "each" ? "Check answer" : last ? "Submit and finish" : "Submit and next"}</button><button class="btn btn-ghost" data-action="skip">Skip</button><span class="spacer"></span><span class="kbd-hint">${q.type === "spr" ? "<kbd>Enter</kbd> to check" : "<kbd>A</kbd>–<kbd>D</kbd> to choose, <kbd>Enter</kbd> to check"}</span></div>`;
    } else {
      actions = `<div class="q-actions"><button class="btn" data-action="next" id="next-btn">${last ? "See results" : "Next question"}</button><span class="spacer"></span><span class="kbd-hint"><kbd>Enter</kbd> for ${last ? "results" : "next"}</span></div>`;
    }
    const dots = s.ids
      .map((id, i) => {
        const rr = s.results[id];
        let c = i === s.idx ? "cur" : "";
        if (rr) c += s.feedback === "each" ? (rr.ok ? " ok" : " bad") : " done";
        return `<i class="${c}"></i>`;
      })
      .join("");
    return `<div class="q-shell">
      <div class="q-bar">
        <div class="q-progress"><span>Question ${s.idx + 1} <span class="of">of ${s.ids.length}</span></span>${s.ids.length <= 60 ? `<span class="q-dots" aria-hidden="true">${dots}</span>` : ""}</div>
        <div class="q-tools">
          <span class="timer num" id="timer" title="${s.timed ? "Time left at test pace" : "Time in this session"}">0:00</span>
          <button class="btn btn-secondary btn-sm flag-btn" data-action="flag" data-id="${esc(q.id)}" aria-pressed="${!!state.marked[q.id]}">⚑ ${state.marked[q.id] ? "Marked" : "Mark for review"}</button>
          ${q.section === "math" ? `<a class="btn btn-secondary btn-sm" href="https://www.desmos.com/calculator" target="_blank" rel="noopener">Calculator ↗</a><button class="btn btn-secondary btn-sm" data-action="open-ref">Reference</button>` : ""}
          <button class="btn btn-ghost btn-sm" data-action="end-session">End</button>
        </div>
      </div>
      <div class="q-body ${body.split ? "split" : ""}">${body.html.replace("__ACTIONS__", actions)}</div>
    </div>
    <p class="muted small">${esc(s.label)}${s.feedback === "end" ? " · Explanations appear when you finish" : ""}</p>`;
  }

  function startTimer() {
    stopTimer();
    const tick = () => {
      const el = document.getElementById("timer");
      if (!el || !session) return;
      const elapsed = (Date.now() - session.startedAt) / 1000;
      if (session.timed) {
        const left = session.limit - elapsed;
        el.textContent = left >= 0 ? fmtClock(left) : "+" + fmtClock(-left);
        el.classList.toggle("over", left < 0);
        if (left <= 0 && session.feedback === "end" && !session.timeUp) {
          session.timeUp = true;
          finishSession();
        }
      } else {
        el.textContent = fmtClock(elapsed);
      }
    };
    tick();
    timerId = setInterval(tick, 1000);
  }
  function stopTimer() {
    if (timerId) clearInterval(timerId);
    timerId = null;
  }

  function submitCurrent() {
    const s = session;
    const q = QBYID.get(s.ids[s.idx]);
    if (s.results[q.id]) return;
    const given = q.type === "spr" ? cleanAns(s.spr) : s.sel;
    if (!given) return;
    const ok = isCorrect(q, given);
    const secs = (Date.now() - s.shownAt) / 1000;
    s.results[q.id] = { ok, given, s: Math.round(secs) };
    recordAttempt(q, ok, given, secs);
    if (s.feedback === "end") advance();
    else {
      render();
      const fb = document.getElementById("feedback");
      if (fb && fb.scrollIntoView) fb.scrollIntoView({ block: "nearest", behavior: "smooth" });
      const nb = document.getElementById("next-btn");
      if (nb) nb.focus({ preventScroll: true });
    }
  }
  function advance() {
    const s = session;
    if (s.idx >= s.ids.length - 1) return finishSession();
    s.idx++;
    s.sel = null;
    s.spr = "";
    s.elim = {};
    s.shownAt = Date.now();
    render();
    scrollTop();
  }

  // ---------------------------------------------------------------------------
  // Session summary
  // ---------------------------------------------------------------------------
  function viewSummary() {
    const sm = lastSummary;
    const done = sm.items.filter((it) => it.r);
    const right = done.filter((it) => it.r.ok).length;
    const mins = (sm.endedAt - sm.startedAt) / 1000;
    const bySkill = new Map();
    for (const it of done) {
      const q = QBYID.get(it.id);
      const v = bySkill.get(q._skill) || { n: 0, ok: 0 };
      v.n++;
      v.ok += it.r.ok ? 1 : 0;
      bySkill.set(q._skill, v);
    }
    const missedIds = done.filter((it) => !it.r.ok).map((it) => it.id);
    let html = `<div class="page-head"><div><p class="eyebrow">${esc(sm.label)}</p><h1>Session results</h1></div><div class="btn-row">${missedIds.length ? `<button class="btn" data-action="retry-ids" data-ids="${esc(missedIds.join(","))}">Retry the ${plural(missedIds.length, "missed question")}</button>` : ""}<a class="btn btn-secondary" href="#dashboard">Dashboard</a></div></div>`;
    if (sm.timeUp) html += `<div class="banner"><p><b>Time's up.</b> The session ended at test pace. Questions you didn't reach aren't counted.</p></div>`;
    html += `<section class="panel"><div class="score-hero"><div class="big num">${right}<small> / ${done.length} correct</small></div><div class="muted">${done.length ? pct(right / done.length) + " accuracy · " : ""}${fmtClock(mins)} total${done.length ? ` · ${Math.round(done.reduce((s, it) => s + (it.r.s || 0), 0) / done.length)} s per question` : ""}${sm.items.length > done.length ? ` · ${sm.items.length - done.length} skipped` : ""}</div></div></section>`;
    if (bySkill.size) {
      html += `<section class="panel"><h2>By skill</h2><div class="table-wrap"><table class="data"><thead><tr><th>Skill</th><th>Domain</th><th class="num">Correct</th><th>Overall level</th></tr></thead><tbody>${[...bySkill.entries()]
        .sort((a, b) => a[1].ok / a[1].n - b[1].ok / b[1].n)
        .map(([sk, v]) => `<tr><td>${esc(sk.name)}</td><td>${esc(sk.domain.name)}</td><td class="num">${v.ok}/${v.n}</td><td>${levelChip(realStats().skill.get(sk.key))}</td></tr>`)
        .join("")}</tbody></table></div></section>`;
    }
    html += `<section class="panel"><div class="panel-head"><h2>Questions</h2><p>Select one to see its explanation</p></div><ol class="qlist">${sm.items
      .map((it, i) => {
        const q = QBYID.get(it.id);
        const res = it.r ? (it.r.ok ? `<span class="chip ok">✓ ${esc(it.r.given)}</span>` : `<span class="chip bad">✗ ${esc(it.r.given)} · answer ${esc(answerLabel(q))}</span>`) : `<span class="chip">Skipped</span>`;
        return `<li><button class="qrow" data-action="view-q" data-id="${esc(q.id)}" data-given="${esc(it.r ? it.r.given : "")}" data-from="summary"><span class="snippet"><b class="num">${i + 1}.</b> ${esc(snippet(q))}</span><span class="tags"><span>${esc(q._skill.name)}</span>·<span>${esc(DIFF_NAMES[q.difficulty] || "")}</span></span><span class="status">${res}</span></button></li>`;
      })
      .join("")}</ol></section>`;
    return html;
  }

  function viewQuestion() {
    const q = QBYID.get(viewer.id);
    const given = viewer.given || "";
    const result = given ? { ok: isCorrect(q, given), given } : null;
    const body = questionBody(q, { locked: true, sel: q.type === "spr" ? null : given, spr: q.type === "spr" ? given : "", elim: {}, result, showAnswer: true });
    const back = viewer.from === "summary" ? `<a class="btn btn-secondary btn-sm" href="#summary">← Back to results</a>` : `<a class="btn btn-secondary btn-sm" href="#${esc(viewer.from)}">← Back</a>`;
    const actions = `<div class="q-actions"><button class="btn" data-action="retry-ids" data-ids="${esc(q.id)}">Try it again</button></div>`;
    return `<div class="btn-row">${back}</div><div class="q-shell"><div class="q-bar"><div class="q-progress">Review</div><div class="q-tools"><button class="btn btn-secondary btn-sm flag-btn" data-action="flag" data-id="${esc(q.id)}" aria-pressed="${!!state.marked[q.id]}">⚑ ${state.marked[q.id] ? "Marked" : "Mark for review"}</button></div></div><div class="q-body ${body.split ? "split" : ""}">${body.html.replace("__ACTIONS__", actions)}</div></div>`;
  }

  // ---------------------------------------------------------------------------
  // Question bank
  // ---------------------------------------------------------------------------
  function bankFilters() {
    return Object.assign({ section: "", domain: "", skill: "", diff: "", status: "", text: "" }, state.prefs.bank || {});
  }
  function bankResults(f) {
    const perQ = realStats().perQ;
    const text = norm(f.text);
    return QUESTIONS.filter((q) => {
      if (f.section && q.section !== f.section) return false;
      if (f.domain && q._dom.key !== f.domain) return false;
      if (f.skill && q._skill.key !== f.skill) return false;
      if (f.diff && q.difficulty !== f.diff) return false;
      if (f.status) {
        const p = perQ.get(q.id);
        if (f.status === "new" && p) return false;
        if (f.status === "correct" && !(p && p.lastOk)) return false;
        if (f.status === "missed" && !(p && !p.lastOk)) return false;
        if (f.status === "marked" && !state.marked[q.id]) return false;
      }
      if (text) {
        if (q._text == null) q._text = norm(q.id + " " + plainText((q.stimulus || "") + " " + (q.stem || "")));
        if (!q._text.includes(text)) return false;
      }
      return true;
    });
  }
  function viewBank() {
    const f = bankFilters();
    const list = bankResults(f);
    const pages = Math.max(1, Math.ceil(list.length / PAGE_SIZE));
    bankPage = Math.min(bankPage, pages - 1);
    const shown = list.slice(bankPage * PAGE_SIZE, (bankPage + 1) * PAGE_SIZE);
    const opt = (v, label, cur) => `<option value="${esc(v)}" ${v === cur ? "selected" : ""}>${esc(label)}</option>`;
    const doms = DOMAINS.filter((d) => !f.section || d.section === f.section);
    const sks = [...SKILLS.values()].filter((s) => (!f.section || s.section === f.section) && (!f.domain || s.domain.key === f.domain) && s.qids.length);
    let html = `<div class="page-head"><div><h1>Question bank</h1><p class="lede">${BANK_LOADED ? `All ${QUESTIONS.length.toLocaleString()} questions from the College Board PSAT question bank` : `${QUESTIONS.length} sample questions`}, filtered by skill, difficulty, and how you did.</p></div></div>`;
    html += sampleBanner();
    html += `<section class="panel"><div class="filters">
      <div class="field"><label for="f-text">Search</label><input type="search" id="f-text" placeholder="Words from the question, or an ID" value="${esc(f.text)}" data-change="bank" data-key="text"></div>
      <div class="field"><label for="f-section">Section</label><select id="f-section" data-change="bank" data-key="section">${opt("", "Both sections", f.section)}${opt("rw", "Reading and Writing", f.section)}${opt("math", "Math", f.section)}</select></div>
      <div class="field"><label for="f-domain">Domain</label><select id="f-domain" data-change="bank" data-key="domain">${opt("", "All domains", f.domain)}${doms.map((d) => opt(d.key, d.name, f.domain)).join("")}</select></div>
      <div class="field"><label for="f-skill">Skill</label><select id="f-skill" data-change="bank" data-key="skill">${opt("", "All skills", f.skill)}${sks.map((s) => opt(s.key, s.name, f.skill)).join("")}</select></div>
      <div class="field"><label for="f-diff">Difficulty</label><select id="f-diff" data-change="bank" data-key="diff">${opt("", "Any difficulty", f.diff)}${DIFFS.map((d) => opt(d, DIFF_NAMES[d], f.diff)).join("")}</select></div>
      <div class="field"><label for="f-status">Your history</label><select id="f-status" data-change="bank" data-key="status">${opt("", "Any", f.status)}${opt("new", "Not tried", f.status)}${opt("correct", "Got right last time", f.status)}${opt("missed", "Missed last time", f.status)}${opt("marked", "Marked for review", f.status)}</select></div>
    </div></section>`;
    html += `<section class="panel"><div class="panel-head"><h2 class="num">${list.length.toLocaleString()} ${list.length === 1 ? "question" : "questions"}</h2>${list.length ? `<div class="btn-row"><button class="btn btn-sm" data-action="practice-bank" data-count="10">Practice 10 of these</button>${list.length > 10 ? `<button class="btn btn-secondary btn-sm" data-action="practice-bank" data-count="0">Practice all ${list.length.toLocaleString()} in order</button>` : ""}</div>` : ""}</div>${
      list.length ? `<ul class="qlist">${shown.map((q) => qRow(q)).join("")}</ul>` : `<div class="empty">No questions match. Clear a filter to see more.</div>`
    }${
      pages > 1
        ? `<div class="pager"><button class="btn btn-secondary btn-sm" data-action="page" data-dir="-1" ${bankPage === 0 ? "disabled" : ""}>← Previous</button><span class="num small">Page ${bankPage + 1} of ${pages}</span><button class="btn btn-secondary btn-sm" data-action="page" data-dir="1" ${bankPage >= pages - 1 ? "disabled" : ""}>Next →</button></div>`
        : ""
    }</section>`;
    return html;
  }

  // ---------------------------------------------------------------------------
  // Review: missed, marked, history, and your data
  // ---------------------------------------------------------------------------
  function viewReview() {
    const tab = state.prefs.reviewTab || "missed";
    const perQ = realStats().perQ;
    const missed = [...perQ.entries()].filter(([, p]) => !p.lastOk).sort((a, b) => b[1].lastAt - a[1].lastAt).map(([id]) => QBYID.get(id)).filter(Boolean);
    const marked = Object.keys(state.marked).filter((id) => state.marked[id] && QBYID.has(id)).map((id) => QBYID.get(id));
    let html = `<div class="page-head"><div><h1>Review</h1><p class="lede">Go back over questions you missed or marked. Retrying a question you missed is the fastest way to fix a weak skill.</p></div></div>`;
    html += `<div>${seg("reviewTab", [["missed", `Missed (${missed.length})`], ["marked", `Marked (${marked.length})`], ["history", "History"]], tab)}</div>`;
    if (tab === "history") {
      const recent = state.attempts.slice(-150).reverse();
      html += `<section class="panel"><div class="panel-head"><h2>Recent answers</h2><p>${plural(state.attempts.length, "answer")} in total</p></div>${
        recent.length
          ? `<div class="table-wrap"><table class="data"><thead><tr><th>When</th><th>Question</th><th>Skill</th><th>Result</th><th class="num">Time</th></tr></thead><tbody>${recent
              .map((a) => {
                const q = QBYID.get(a.q);
                if (!q) return "";
                return `<tr><td class="num">${esc(new Date(a.at).toLocaleString(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }))}</td><td><a href="#review" data-action="view-q" data-id="${esc(q.id)}" data-given="${esc(a.a || "")}" data-from="review">${esc(q.id)}</a></td><td>${esc(q._skill.name)}</td><td>${a.ok ? `<span class="chip ok">✓ ${esc(a.a)}</span>` : `<span class="chip bad">✗ ${esc(a.a)}</span>`}</td><td class="num">${a.s ? a.s + " s" : "–"}</td></tr>`;
              })
              .join("")}</tbody></table></div>`
          : `<div class="empty">No answers yet.</div>`
      }</section>`;
    } else {
      const list = tab === "missed" ? missed : marked;
      const action = tab === "missed" ? "Retry missed" : "Practice marked";
      html += `<section class="panel"><div class="panel-head"><h2>${tab === "missed" ? "Missed last time" : "Marked for review"}</h2>${list.length ? `<button class="btn btn-sm" data-action="retry-ids" data-ids="${esc(list.slice(0, 100).map((q) => q.id).join(","))}">${action} (${Math.min(100, list.length)})</button>` : ""}</div>${
        list.length
          ? `<ul class="qlist">${list
              .slice(0, 200)
              .map((q) => {
                const p = perQ.get(q.id);
                return `<li><button class="qrow" data-action="view-q" data-id="${esc(q.id)}" data-given="${esc(p ? p.lastAnswer : "")}" data-from="review"><span class="snippet">${esc(snippet(q))}</span><span class="tags"><span>${esc(SECTIONS[q.section].short)}</span>·<span>${esc(q._skill.name)}</span>·<span>${esc(DIFF_NAMES[q.difficulty] || "")}</span></span><span class="status">${statusChips(q.id)}</span></button></li>`;
              })
              .join("")}</ul>`
          : `<div class="empty">${tab === "missed" ? "Nothing here yet. Questions you get wrong show up here." : "Use “Mark for review” on any question to save it here."}</div>`
      }</section>`;
    }
    const inArtifact = !!(window.claude && typeof window.claude.use === "function");
    html += `<section class="panel"><h2>Your data</h2><p class="muted" style="margin-top:6px">${
      cloud.on ? "Your progress is saved to your account and in this browser." : "Your progress is saved in this browser. Export it to move it to another device."
    }</p><div class="btn-row" style="margin-top:14px">${inArtifact ? "" : `<button class="btn btn-secondary btn-sm" data-action="export">Export progress</button>`}<label class="btn btn-secondary btn-sm" for="import-file">Import progress</label><input type="file" id="import-file" accept="application/json,.json" data-change="import" hidden>${
      resetArmed
        ? `<span class="small">Delete all ${plural(state.attempts.length, "answer")}? This can't be undone.</span><button class="btn btn-sm" data-action="reset-confirm" style="background:var(--bad);color:#fff">Delete everything</button><button class="btn btn-ghost btn-sm" data-action="reset-cancel">Cancel</button>`
        : `<button class="btn btn-ghost btn-sm" data-action="reset">Reset progress…</button>`
    }</div><p class="small muted" id="data-msg" style="margin-top:10px"></p></section>`;
    return html;
  }

  function renderFooter() {
    const el = document.getElementById("footer");
    if (!el) return;
    if (BANK_LOADED) {
      const when = BANK_INFO && BANK_INFO.fetchedAt ? new Date(BANK_INFO.fetchedAt).toLocaleDateString(undefined, { year: "numeric", month: "long", day: "numeric" }) : "";
      el.innerHTML = `Questions and explanations come from the College Board SAT Suite Question Bank${BANK_INFO && BANK_INFO.exam ? ` (${esc(BANK_INFO.exam)})` : ""}${when ? `, downloaded ${esc(when)}` : ""}. ${QUESTIONS.length.toLocaleString()} questions. This study site is not affiliated with or endorsed by College Board.`;
    } else {
      el.textContent = `Sample mode: ${QUESTIONS.length} original practice questions written for this site, not taken from College Board.`;
    }
  }

  const VIEWS = { dashboard: viewDashboard, practice: viewPractice, bank: viewBank, review: viewReview, session: viewSession, summary: viewSummary, question: viewQuestion };

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------
  const actions = {
    smart(el) {
      const sec = el.dataset.section || "";
      const count = +el.dataset.count || 10;
      const set = smartSet(sec, count);
      startSession(set.ids, { label: set.label });
    },
    "practice-skill"(el) {
      const sk = SKILLS.get(el.dataset.skill);
      if (sk && sk.qids.length) startSession(skillSet(sk, 10), { label: sk.name });
    },
    "hide-demo"() {
      setPref("hideDemo", true);
      render();
    },
    "show-demo"() {
      setPref("hideDemo", false);
      render();
    },
    seg(el) {
      const name = el.dataset.name;
      let value = el.dataset.value;
      if (name === "smartCount" || name === "c.count") value = +value;
      if (name.startsWith("c.")) {
        const c = customDefaults();
        c[name.slice(2)] = value;
        setPref("custom", c);
      } else {
        setPref(name, value);
      }
      render();
    },
    "toggle-domain"(el) {
      const c = customDefaults();
      const d = DOMAINS.find((x) => x.key === el.dataset.domain);
      const allOn = d.skills.every((s) => !c.exclude[s.key]);
      for (const s of d.skills) {
        if (allOn) c.exclude[s.key] = true;
        else delete c.exclude[s.key];
      }
      setPref("custom", c);
      render();
    },
    "start-custom"() {
      const c = customDefaults();
      const pool = customPool(c);
      const ids = (c.from === "missed" || c.from === "marked" ? shuffle(pool) : pickQuestions(pool, pool.length)).slice(0, c.count || pool.length).map((q) => q.id);
      startSession(ids, { label: "Custom set", feedback: c.feedback, timed: c.timer === "pace" });
    },
    resume() {
      go("session");
    },
    "end-session"() {
      if (route() === "session") finishSession();
      else {
        session = null;
        render();
      }
    },
    choose(el) {
      if (!session) return;
      const L = el.dataset.letter;
      session.sel = L;
      if (session.elim[L]) delete session.elim[L];
      view.querySelectorAll(".choice").forEach((c) => {
        const on = c.dataset.letter === L;
        c.classList.toggle("selected", on);
        c.querySelector(".choice-btn").setAttribute("aria-pressed", String(on));
        c.classList.toggle("eliminated", !!session.elim[c.dataset.letter]);
      });
      const b = document.getElementById("check-btn");
      if (b) b.disabled = false;
    },
    eliminate(el) {
      if (!session) return;
      const L = el.dataset.letter;
      if (session.elim[L]) delete session.elim[L];
      else {
        session.elim[L] = true;
        if (session.sel === L) session.sel = null;
      }
      view.querySelectorAll(".choice").forEach((c) => {
        c.classList.toggle("eliminated", !!session.elim[c.dataset.letter]);
        const on = c.dataset.letter === session.sel;
        c.classList.toggle("selected", on);
        c.querySelector(".choice-btn").setAttribute("aria-pressed", String(on));
      });
      const b = document.getElementById("check-btn");
      if (b) b.disabled = !session.sel;
    },
    check() {
      if (session) submitCurrent();
    },
    skip() {
      if (session) advance();
    },
    next() {
      if (session) advance();
    },
    flag(el) {
      const id = el.dataset.id;
      if (state.marked[id]) delete state.marked[id];
      else state.marked[id] = 1;
      persist();
      el.setAttribute("aria-pressed", String(!!state.marked[id]));
      el.textContent = "⚑ " + (state.marked[id] ? "Marked" : "Mark for review");
    },
    "open-ref"() {
      const d = document.getElementById("refsheet");
      if (d && d.showModal) d.showModal();
    },
    "close-ref"() {
      const d = document.getElementById("refsheet");
      if (d) d.close();
    },
    "retry-ids"(el) {
      const ids = el.dataset.ids.split(",").filter(Boolean);
      startSession(ids, { label: ids.length === 1 ? "Retry" : "Retry missed questions" });
    },
    "open-q"(el) {
      const f = bankFilters();
      const list = bankResults(f).map((q) => q.id);
      const i = list.indexOf(el.dataset.id);
      startSession(list.slice(Math.max(0, i), Math.max(0, i) + 100), { label: "Question bank" });
    },
    "view-q"(el, e) {
      if (e) e.preventDefault();
      viewer = { id: el.dataset.id, given: el.dataset.given || "", from: el.dataset.from || "review" };
      go("question");
      scrollTop();
    },
    "practice-bank"(el) {
      const list = bankResults(bankFilters());
      const n = +el.dataset.count;
      const ids = n ? pickQuestions(list, n).map((q) => q.id) : list.map((q) => q.id);
      startSession(ids, { label: "Question bank" });
    },
    page(el) {
      bankPage += +el.dataset.dir;
      render();
      scrollTop();
    },
    export() {
      const blob = new Blob([JSON.stringify({ app: "psat-prep", version: 1, exportedAt: new Date().toISOString(), attempts: state.attempts, marked: state.marked }, null, 1)], { type: "application/json" });
      const a = document.createElement("a");
      a.href = URL.createObjectURL(blob);
      a.download = "psat-prep-progress-" + dayKey(Date.now()) + ".json";
      document.body.appendChild(a);
      a.click();
      setTimeout(() => {
        URL.revokeObjectURL(a.href);
        a.remove();
      }, 1000);
    },
    reset() {
      resetArmed = true;
      render();
    },
    "reset-cancel"() {
      resetArmed = false;
      render();
    },
    "reset-confirm"() {
      resetArmed = false;
      state.attempts = [];
      state.marked = {};
      invalidate();
      persist();
      render();
    },
  };
  document.addEventListener("click", (e) => {
    const el = e.target.closest("[data-action]");
    if (!el || el.disabled) return;
    const fn = actions[el.dataset.action];
    if (fn) fn(el, e);
  });

  let textTimer = null;
  function onFieldChange(e) {
    const el = e.target;
    const kind = el.dataset && el.dataset.change;
    if (!kind) return;
    if (kind === "skill") {
      const c = customDefaults();
      if (el.checked) delete c.exclude[el.dataset.skill];
      else c.exclude[el.dataset.skill] = true;
      setPref("custom", c);
      updateMatchCount();
    } else if (kind === "diff") {
      const c = customDefaults();
      c.diff[el.dataset.diff] = el.checked;
      setPref("custom", c);
      updateMatchCount();
    } else if (kind === "bank") {
      const f = bankFilters();
      f[el.dataset.key] = el.value;
      if (el.dataset.key === "section") f.domain = f.skill = "";
      if (el.dataset.key === "domain") f.skill = "";
      setPref("bank", f);
      bankPage = 0;
      if (el.dataset.key === "text") {
        clearTimeout(textTimer);
        textTimer = setTimeout(() => {
          const pos = el.selectionStart;
          render();
          const again = document.getElementById("f-text");
          if (again) {
            again.focus();
            try {
              again.setSelectionRange(pos, pos);
            } catch (err) {
              /* some inputs don't support selection */
            }
          }
        }, 250);
      } else render();
    } else if (kind === "spr" && session) {
      const cleaned = el.value.replace(/[^0-9./\-−]/g, "");
      if (cleaned !== el.value) el.value = cleaned;
      session.spr = cleaned;
      const pv = document.getElementById("spr-preview");
      if (pv) pv.innerHTML = sprPreview(cleaned);
      const b = document.getElementById("check-btn");
      if (b) b.disabled = !cleanAns(cleaned);
    } else if (kind === "import" && el.files && el.files[0]) {
      const reader = new FileReader();
      reader.onload = () => {
        const msg = document.getElementById("data-msg");
        try {
          const data = JSON.parse(reader.result);
          const incoming = (data.attempts || []).filter(validAttempt);
          const seen = new Set(state.attempts.map((a) => a.q + "@" + a.at));
          let added = 0;
          for (const a of incoming) {
            const k = a.q + "@" + a.at;
            if (!seen.has(k)) {
              seen.add(k);
              state.attempts.push(a);
              added++;
            }
          }
          state.attempts.sort((a, b) => a.at - b.at);
          Object.assign(state.marked, data.marked || {});
          invalidate();
          persist();
          render();
          const m2 = document.getElementById("data-msg");
          if (m2) m2.textContent = `Imported ${plural(added, "new answer")}.`;
        } catch (err) {
          if (msg) msg.textContent = "That file isn't a PSAT Prep progress export. Choose the .json file made by Export progress.";
        }
      };
      reader.readAsText(el.files[0]);
    }
  }
  document.addEventListener("change", onFieldChange);
  document.addEventListener("input", (e) => {
    const k = e.target.dataset && e.target.dataset.change;
    if (k === "spr" || (k === "bank" && e.target.dataset.key === "text")) onFieldChange(e);
  });

  document.addEventListener("keydown", (e) => {
    if (route() !== "session" || !session || e.metaKey || e.ctrlKey || e.altKey) return;
    const q = QBYID.get(session.ids[session.idx]);
    const answered = !!session.results[q.id];
    const inInput = e.target && (e.target.tagName === "INPUT" || e.target.tagName === "SELECT" || e.target.tagName === "TEXTAREA");
    if (e.key === "Enter") {
      const t = e.target;
      if (t && t.tagName === "BUTTON" && !t.matches("#check-btn,#next-btn,.choice-btn")) return;
      e.preventDefault();
      // Enter on an unselected choice selects it; on the selected one it checks.
      if (t && t.matches && t.matches(".choice-btn") && session.sel !== t.dataset.letter && !answered) return actions.choose(t);
      if (answered) advance();
      else submitCurrent();
      return;
    }
    if (inInput || answered || q.type === "spr") return;
    const L = e.key.toUpperCase();
    const i = LETTERS.indexOf(L);
    if (i >= 0 && i < q.choices.length) {
      const btn = view.querySelector(`.choice-btn[data-letter="${L}"]`);
      if (btn) actions.choose(btn);
    }
  });

  window.addEventListener("hashchange", () => {
    render();
  });

  // ---------------------------------------------------------------------------
  // Boot
  // ---------------------------------------------------------------------------
  function start(hot) {
    loadLocal();
    if (hot && typeof hot === "object") {
      if (hot.session && hot.session.ids && hot.session.ids.every((id) => QBYID.has(id))) session = hot.session;
      if (hot.lastSummary) lastSummary = hot.lastSummary;
      if (hot.viewer) viewer = hot.viewer;
    }
    render();
    setSync("local");
    initCloud();
  }
  const hotApi = window.claude && window.claude.hot;
  try {
    if (hotApi && typeof hotApi.snapshot === "function") hotApi.snapshot(() => ({ session, lastSummary, viewer }));
  } catch (e) {
    /* hot reload is optional */
  }
  if (hotApi && typeof hotApi.ready === "function") hotApi.ready(start);
  else start((hotApi && hotApi.data) || {});
})();
