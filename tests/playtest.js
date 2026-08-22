#!/usr/bin/env node
/* SPOT THE LIE — rule-16 real-browser CDP playthrough v2.
 * Key fix: menu buttons are Godot Controls rendered INSIDE the canvas, so
 * clicks must go through the canvas transform. We compute the game->page
 * transform live (sm: min(w/1280,h/720) centered) and click the DAILY
 * button at its known in-game rect center (476..804, 280..336).
 * Then diffs are clicked via window.SPOT_DEBUG manifest (left-half coords).
 * Usage: node tests/playtest.js [URL]
 */
const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");

const URL = process.argv[2] || "https://sxaad69.github.io/spot-the-lie/";
const PORT = 19000 + Math.floor(Math.random() * 2000);
const OUT = path.join(__dirname, "..", "docs", "qa-evidence");
fs.mkdirSync(OUT, { recursive: true });

let ws, msgId = 0;
const pending = new Map();
const consoleErrors = [];

function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++msgId;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
    setTimeout(() => reject(new Error("timeout " + method)), 30000);
  });
}

function onMessage(data) {
  const m = JSON.parse(data);
  if (m.id && pending.has(m.id)) {
    const p = pending.get(m.id);
    pending.delete(m.id);
    if (m.error) p.reject(new Error(m.error.message)); else p.resolve(m.result);
  } else if (m.method === "Runtime.consoleAPICalled" && m.params.type === "error") {
    consoleErrors.push(JSON.stringify(m.params.args).slice(0, 300));
  } else if (m.method === "Runtime.exceptionThrown") {
    consoleErrors.push(String(m.params.exceptionDetails?.exception?.description || "exc").slice(0, 300));
  }
}

async function evaluate(expr) {
  const r = await send("Runtime.evaluate", { expression: expr, returnByValue: true, awaitPromise: true });
  if (r.exceptionDetails) throw new Error("eval: " + JSON.stringify(r.exceptionDetails).slice(0, 250));
  return r.result.value;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** page coords for in-game coords (game 1280x720 letterboxed inside canvas). */
async function gamePoint(gx, gy) {
  return evaluate(`(() => {
    const c = canvas.getBoundingClientRect();
    const s = Math.min(c.width / 1280, c.height / 720);
    return { x: c.left + (c.width - 1280*s)/2 + ${gx}*s,
             y: c.top + (c.height - 720*s)/2 + ${gy}*s };
  })()`);
}

async function click(x, y) {
  await send("Input.dispatchMouseEvent", { type: "mouseMoved", x, y });
  for (const type of ["mousePressed", "mouseReleased"]) {
    await send("Input.dispatchMouseEvent", {
      type, x, y, button: "left", buttons: type === "mousePressed" ? 1 : 0, clickCount: 1,
    });
    await sleep(50);
  }
}

async function shot(name) {
  const r = await send("Page.captureScreenshot", { format: "png" });
  fs.writeFileSync(path.join(OUT, name), Buffer.from(r.data, "base64"));
}

let pass = 0, fail = 0;
function check(cond, label) {
  if (cond) { pass++; console.log("  PASS " + label); }
  else { fail++; console.log("  FAIL " + label); }
}

async function clearBoard(label) {
  const manifest = await evaluate(`window.SPOT_DEBUG ? window.SPOT_DEBUG.manifest : null`);
  if (!manifest) throw new Error("no SPOT_DEBUG hook");
  // click each diff epicenter twice (left + right half) to be robust
  for (const m of manifest) {
    const e = m.epicenters[0];
    const pL = await gamePoint(e.x + 4, e.y + 4);
    await click(pL.x, pL.y);
    const pR = await gamePoint(BoardOX_R() + e.x + 4, e.y + 4);
    await click(pR.x, pR.y);
    await sleep(400);
  }
  const met = await evaluate(`window.SPOT_METRICS ? window.SPOT_METRICS() : null`);
  check(met && met.cleared === true, `${label}: cleared (${met.found}/${met.total}, wrong=${met.wrong_taps})`);
  return met;
}
function BoardOX_R() { return 610; } // HALF_W 550 + GAP 60

async function main() {
  console.log(`SMOKE-PLAYTEST v2 — ${URL}`);
  const chrom = spawn("/usr/bin/chromium-browser", [
    "--headless=new", `--remote-debugging-port=${PORT}`,
    "--window-size=1280,760", "--no-sandbox", "--disable-gpu",
    `--user-data-dir=/tmp/qa-stl2-${Date.now()}`, "--autoplay-policy=no-user-gesture-required",
    "about:blank",
  ], { stdio: "ignore" });

  try {
    let target = null;
    for (let i = 0; i < 20; i++) {
      await sleep(400);
      try {
        const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
        target = list.find((t) => t.type === "page");
        if (target) break;
      } catch (e) {}
    }
    if (!target) throw new Error("no page target");

    ws = new WebSocket(target.webSocketDebuggerUrl);
    ws.onmessage = (ev) => onMessage(ev.data);
    await new Promise((res) => (ws.onopen = res));
    await send("Page.enable"); await send("Runtime.enable");

    const t0 = Date.now();
    await send("Page.navigate", { url: URL });
    // wait for canvas
    let ok = false;
    while (Date.now() - t0 < 60000) {
      try {
        if ((await evaluate(`typeof canvas !== 'undefined' && !!canvas`)) === true) { ok = true; break; }
      } catch (e) {}
      await sleep(500);
    }
    check(ok, "engine booted");
    await sleep(3000); // first frame + font load
    await shot("01-boot.png");

    // DAILY button: in-game rect (476..804, 280..336) -> center (640, 308)
    const dBtn = await gamePoint(640, 308);
    await click(dBtn.x, dBtn.y);
    await sleep(1200);
    const dailySeed = await evaluate(`window.SPOT_DEBUG ? window.SPOT_DEBUG.seed : null`);
    check(typeof dailySeed === "string" && dailySeed.startsWith("DAILY-"), `DAILY mode entered: ${dailySeed}`);
    const m1 = await clearBoard("DAILY board");
    await shot("02-daily-cleared.png");

    // MENU -> MIRROR
    const menuBtn = await gamePoint(640, 706); // MENU row
    await click(menuBtn.x, menuBtn.y);
    await sleep(800);
    const mBtn = await gamePoint(640, 402); // MirrorBtn (3rd): y=374+28
    await click(mBtn.x, mBtn.y);
    await sleep(1000);
    const m2 = await clearBoard("MIRROR board");
    await shot("03-mirror-cleared.png");

    // MENU -> DRIFT
    await click(menuBtn.x, menuBtn.y);
    await sleep(800);
    const dBtn2 = await gamePoint(640, 449); // DriftBtn (4th)
    await click(dBtn2.x, dBtn2.y);
    await sleep(1000);
    const m3 = await clearBoard("DRIFT board 1");
    await shot("04-drift-cleared.png");

    const metrics = await evaluate(`window.SPOT_METRICS ? window.SPOT_METRICS() : null`);
    check(metrics !== null, "metrics readable after runs");
    await shot("05-final.png");

    check(consoleErrors.length === 0, `console clean (${consoleErrors.length} errors${consoleErrors.length ? ": " + consoleErrors[0] : ""})`);

    console.log("\n=== SMOKE-PLAYTEST REPORT — SPOT THE LIE v1 ===");
    console.log(`CONSOLE ERRORS: ${consoleErrors.length}${consoleErrors.length ? " — " + consoleErrors.slice(0, 3).join(" | ") : ""}`);
    console.log(`CHECKS: ${pass} pass / ${fail} fail`);
    console.log(`SCREENSHOTS: ${OUT}/01-05.png`);
    console.log(`VERDICT: ${fail === 0 ? "RUNNABLE" : "NEEDS-FIX"}`);
    console.log("FUN: explicitly NOT evaluated — human board verdict required");
    process.exitCode = fail === 0 ? 0 : 1;
  } finally {
    chrom.kill();
  }
}

main().catch((e) => { console.error("PLAYTEST ERROR:", e.message); process.exit(2); });
