// W1 feeler verification harness — extracts the generator/salience-floor from index.html
// and stress-tests it across seeds. Throwaway, not part of the shipped game.
const fs = require("fs");
const vm = require("vm");
const path = require("path");

const html = fs.readFileSync(path.join(__dirname, "index.html"), "utf8");
const m = html.match(/<script>([\s\S]*?)<\/script>/);
if (!m) { console.error("FAIL: no script block"); process.exit(1); }
let src = m[1];

// Neutralize DOM so only the logic loads.
const sandbox = {
  console: { log: () => {}, table: () => {}, error: () => {} },
  document: new Proxy({}, { get: () => () => {} }),
};
sandbox.window = sandbox;
sandbox.performance = { now: () => Date.now() };
vm.createContext(sandbox);

// Cut off at the render layer: keep RNG + generation only.
src = src.slice(0, src.indexOf("/* ---------- render"));
vm.runInContext(src + `\nthis.__exports = { generate, NUM_DIFFS, FLOOR_PX };`, sandbox);
const { generate, NUM_DIFFS, FLOOR_PX } = sandbox.__exports;

let fails = 0;
const fail = (msg) => { fails++; console.error("FAIL:", msg);
  if (fails > 20) { console.error("too many failures, aborting"); process.exit(1); } };

const ALLOWED = new Set(["add", "remove", "flip", "swap-position", "resize"]);

// ---- T1: every seed generates exactly N structural diffs ----
const seedList = [];
for (let i = 0; i < 2000; i++) {
  // mix: plain words, XXXX-XXXX daily-format strings, numbers
  const r = i % 3;
  seedList.push(r === 0 ? "TEST-" + String(1000 + i)
              : r === 1 ? String(1 + i * 7919)
              : "seed" + i + "-daily");
}
let classCounts = {};
let travelSum = 0, travelMin = Infinity, floorHits = 0;
for (const s of seedList) {
  let g;
  try { g = generate(s); } catch (e) { fail(`seed ${s}: generator exhausted (${e.message})`); continue; }
  if (g.muts.length !== NUM_DIFFS) fail(`seed ${s}: ${g.muts.length} diffs != ${NUM_DIFFS}`);
  const seenIds = new Set();
  for (const mu of g.muts) {
    if (!ALLOWED.has(mu.cls)) fail(`seed ${s}: illegal mutation class "${mu.cls}"`);
    if (mu.cls.toLowerCase().includes("color") || mu.cls.toLowerCase().includes("recolor"))
      fail(`seed ${s}: recolor-class present (accessibility pin)`);
    // answer-key integrity: every accepted mutation met its effective floor
    if (mu.travel < mu.effFloor - 1e-6) fail(`seed ${s}: accepted mutation below floor ${mu.travel}<${mu.effFloor}`);
    if (Math.abs(mu.effFloor - (FLOOR_PX * (mu.neighbours > 3 ? 1.35 : 1))) > 1e-6)
      fail(`seed ${s}: effFloor miscomputed for neighbours=${mu.neighbours}`);
    classCounts[mu.cls] = (classCounts[mu.cls] || 0) + 1;
    travelSum += mu.travel; travelMin = Math.min(travelMin, mu.travel); floorHits++;
    for (const id of [mu.target.id, mu.target2 && mu.target2.id]) if (id != null) seenIds.add(id);
  }
  // anti-cluster: pairwise epicenter separation >= MIN_CLEAR (66)
  const eps = g.muts.flatMap(mu => mu.epicenters);
  for (let a = 0; a < eps.length; a++) for (let b = a + 1; b < eps.length; b++) {
    const d = Math.hypot(eps[a].x - eps[b].x, eps[a].y - eps[b].y);
    if (d < 66 - 1e-6) fail(`seed ${s}: epicenters ${a}/${b} only ${d.toFixed(1)}px apart (<66)`);
  }
}
console.log(`T1 ${seedList.length} seeds x ${NUM_DIFFS} diffs, classes+floor+anti-cluster:`,
            fails === 0 ? "PASS" : `FAIL(${fails})`);
console.log("   class mix:", JSON.stringify(classCounts));
console.log(`   edge-travel px: min=${travelMin.toFixed(1)} avg=${(travelSum / floorHits).toFixed(1)} (floor base ${FLOOR_PX})`);

// ---- T2: determinism — same seed => byte-identical manifest ----
let detFails = 0;
for (const s of ["DAILY-2026", "ZZ91-KK23", "42"]) {
  const norm = g => JSON.stringify(g.muts.map(x => ({ c: x.cls, t: x.target.id, t2: x.target2 ? x.target2.id : null, ep: x.epicenters, tr: x.travel })));
  if (norm(generate(s)) !== norm(generate(s))) { fail(`seed ${s}: nondeterministic manifest`); detFails++; }
}
console.log("T2 determinism:", detFails === 0 ? "PASS" : "FAIL");

// ---- T3: distinct seeds => distinct puzzles (procedural claim is real) ----
const sigs = new Set();
for (const s of seedList.slice(0, 300)) {
  const g = generate(s);
  sigs.add(JSON.stringify(g.muts.map(x => [x.cls, x.target.id, Math.round(x.epicenters[0].x), Math.round(x.epicenters[0].y)])));
}
console.log(`T3 puzzle variety: ${sigs.size}/300 unique signatures:`, sigs.size > 290 ? "PASS" : "FAIL");

// ---- T4: rejection log proves the salience floor is ACTIVE (reject-and-regenerate happens) ----
let seedsWithRejections = 0;
for (const s of seedList.slice(0, 500)) {
  const g = generate(s);
  if (g.log.some(l => l.rejected)) seedsWithRejections++;
}
console.log(`T4 floor rejections occurred on ${seedsWithRejections}/500 seeds:`,
            seedsWithRejections > 50 ? "PASS (floor genuinely binding)" :
            seedsWithRejections > 0 ? "WEAK (rarely binding)" : "FAIL (floor never fires — decorative)");

console.log(fails === 0 ? "\nHARNESS RESULT: ALL PASS" : `\nHARNESS RESULT: ${fails} FAILURES`);
process.exit(fails === 0 ? 0 : 1);
