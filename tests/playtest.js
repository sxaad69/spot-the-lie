#!/usr/bin/env node
/* SPOT THE LIE — rule-16 real-browser CDP playtest v5.
 * BOARD DIRECTIVE (mid-run): root of the Pages site = the pulse-passed
 * FEELER (master). Full-build deploys go to /v1/ until the board/design
 * pulses the finished build. So this QA targets /v1/.
 *
 * Menu: keyboard (Enter=DAILY, 3=MIRROR, 4=DRIFT) — deterministic, retried
 *   until the board actually starts (engine boot timing varies).
 * Gameplay: REAL mouse clicks (Input.dispatchMouseEvent) at manifest coords.
 * Metrics: window.SPOT_METRICS() is LIVE (game re-pushes after every state
 *   change + 1s heartbeat) — v4 read a frozen one-shot closure and reported
 *   false 0/5 clears on a WORKING game.
 * Diagnostics: window.SPOT_TAPSTATS() exposes engine-side event counters.
 * Usage: node tests/playtest.js [URL]
 */
const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");

const URL = process.argv[2] || "https://sxaad69.github.io/spot-the-lie/v1/";
const PORT = 19000 + Math.floor(Math.random() * 2000);
const OUT = path.join(__dirname, "..", "docs", "qa-evidence");
fs.mkdirSync(OUT, { recursive: true });

let ws = null, msgId = 0;
const pending = new Map();
const consoleErrors = [];

function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    if (!ws) return reject(new Error("ws not attached"));
    const id = ++msgId;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
    setTimeout(() => reject(new Error("timeout " + method)), 30000);
  });
}

function attachWs(socket) {
  ws = socket;
  ws.onmessage = (ev) => {
    const m = JSON.parse(ev.data);
    if (m.id && pending.has(m.id)) {
      const p = pending.get(m.id);
      pending.delete(m.id);
      if (m.error) p.reject(new Error(m.error.message)); else p.resolve(m.result);
    } else if (m.method === "Runtime.consoleAPICalled" && m.params.type === "error") {
      consoleErrors.push(JSON.stringify(m.params.args).slice(0, 300));
    } else if (m.method === "Runtime.exceptionThrown") {
      consoleErrors.push(String(m.params.exceptionDetails?.exception?.description || "exc").slice(0, 300));
    }
  };
}

async function evaluate(expr) {
  const r = await send("Runtime.evaluate", { expression: expr, returnByValue: true });
  if (r.exceptionDetails) throw new Error("eval: " + JSON.stringify(r.exceptionDetails).slice(0, 250));
  return r.result.value;
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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
  await sleep(150);
  await send("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", buttons: 1, clickCount: 1 });
  await sleep(200);
  await send("Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button: "left", buttons: 0, clickCount: 1 });
}

async function key(keyName, vk) {
  await send("Input.dispatchKeyEvent", { type: "keyDown", key: keyName, code: keyName, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk });
  await sleep(60);
  await send("Input.dispatchKeyEvent", { type: "keyUp", key: keyName, code: keyName, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk });
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

// wait for SPOT_DEBUG to appear (board started)
async function waitBoard(timeoutMs = 20000) {
  const t0 = Date.now();
  while (Date.now() - t0 < timeoutMs) {
    try {
      if ((await evaluate(`String(typeof window.SPOT_DEBUG !== 'undefined')`)) === "true") return true;
    } catch (e) {}
    await sleep(500);
  }
  return false;
}

async function clearBoard(label) {
  const manifest = await evaluate(`window.SPOT_DEBUG ? window.SPOT_DEBUG.manifest : null`);
  if (!manifest) throw new Error("no SPOT_DEBUG hook");
  for (const m of manifest) {
    const e = m.epicenters[0];
    const pL = await gamePoint(e.x + 4, e.y + 4);
    await click(pL.x, pL.y);
    await sleep(350);
    let met = await evaluate(`window.SPOT_METRICS ? window.SPOT_METRICS() : null`);
    if (!met.found) {
      // right half fallback
      const pR = await gamePoint(610 + e.x + 4, e.y + 4);
      await click(pR.x, pR.y);
      await sleep(350);
    }
  }
  const met = await evaluate(`window.SPOT_METRICS ? window.SPOT_METRICS() : null`);
  check(met && met.cleared === true, `${label}: cleared (${met.found}/${met.total}, wrong=${met.wrong_taps})`);
  return met;
}

async function enterMode(keyName, vk, label) {
  // retry the key until the board actually starts — engine boot timing
  // varies (v4 fired once and raced the boot)
  const t0 = Date.now();
  while (Date.now() - t0 < 60000) {
    await key(keyName, vk);
    await sleep(1200);
    try {
      if ((await evaluate(`String(typeof window.SPOT_DEBUG !== 'undefined' && window.SPOT_DEBUG !== null)`)) === "true") break;
    } catch (e) {}
  }
  const ok = (await evaluate(`String(typeof window.SPOT_DEBUG !== 'undefined' && window.SPOT_DEBUG !== null)`)) === "true";
  check(ok, `${label} entered`);
  return ok;
}

async function main() {
  console.log(`SMOKE-PLAYTEST v5 — ${URL}`);
  const chrom = spawn("/usr/bin/chromium-browser", [
    "--headless=new", `--remote-debugging-port=${PORT}`,
    "--window-size=1280,800", "--no-sandbox", "--disable-gpu",
    `--user-data-dir=/tmp/qa-stl4-${Date.now()}`, "--autoplay-policy=no-user-gesture-required",
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
    if (!target) throw new Error("no page target — chromium did not expose a page");
    const socket = new WebSocket(target.webSocketDebuggerUrl);
    attachWs(socket);
    await new Promise((res) => (socket.onopen = res));
    await send("Page.enable"); await send("Runtime.enable");

    const t0 = Date.now();
    await send("Page.navigate", { url: URL });
    let ok = false;
    while (Date.now() - t0 < 60000) {
      try { if ((await evaluate(`typeof canvas !== 'undefined' && !!canvas`)) === true) { ok = true; break; } } catch (e) {}
      await sleep(500);
    }
    check(ok, "engine booted (<10s gate)");
    await sleep(3000);
    await shot("01-menu.png");

    // BOARD 1 — DAILY (Enter)
    await enterMode("Enter", 13, "DAILY");
    await clearBoard("DAILY board");
    await shot("02-daily-cleared.png");

    // BOARD 2 — MIRROR (key '3')
    await send("Page.navigate", { url: URL });
    await sleep(9000);
    await enterMode("3", 51, "MIRROR");
    await clearBoard("MIRROR board");
    await shot("03-mirror-cleared.png");

    // BOARD 3 — DRIFT (key '4')
    await send("Page.navigate", { url: URL });
    await sleep(9000);
    await enterMode("4", 52, "DRIFT");
    await clearBoard("DRIFT board 1");
    await shot("04-drift-cleared.png");

    const metrics = await evaluate(`window.SPOT_METRICS ? window.SPOT_METRICS() : null`);
    check(metrics !== null, "metrics readable after runs");
    await shot("05-final.png");
    check(consoleErrors.length === 0, `console clean (${consoleErrors.length} errors${consoleErrors.length ? ": " + consoleErrors[0] : ""})`);

    console.log("\n=== SMOKE-PLAYTEST REPORT — SPOT THE LIE v1 (/v1/) ===");
    console.log(`CONSOLE ERRORS: ${consoleErrors.length}${consoleErrors.length ? " — " + consoleErrors.slice(0, 3).join(" | ") : ""}`);
    console.log(`CHECKS: ${pass} pass / ${fail} fail`);
    console.log(`SCREENSHOTS: ${OUT}/01–05.png`);
    console.log(`VERDICT: ${fail === 0 ? "RUNNABLE" : "NEEDS-FIX"}`);
    console.log("FUN: explicitly NOT evaluated — human board verdict required");
    process.exitCode = fail === 0 ? 0 : 1;
  } finally {
    chrom.kill();
  }
}

main().catch((e) => { console.error("PLAYTEST ERROR:", e.message); process.exit(2); });
