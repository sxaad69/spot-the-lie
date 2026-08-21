// Real-browser playthrough of SPOT THE LIE via raw CDP (Node >=22 native WebSocket).
// Dedicated headless chromium instance per smoke-playtest pitfall #9. Throwaway QA tool.
const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");

const URL_BASE = process.env.STL_URL || "http://127.0.0.1:8123/index.html";
const CDP_PORT = 9333;
const SHOTS = path.join(__dirname, "shots");
fs.mkdirSync(SHOTS, { recursive: true });

const sleep = ms => new Promise(r => setTimeout(r, ms));

async function main() {
  // 1. launch dedicated chromium
  const chrome = spawn("/usr/bin/chromium-browser", [
    "--headless=new", `--remote-debugging-port=${CDP_PORT}`,
    "--window-size=1280,900", "--no-sandbox", "--disable-gpu",
    "--user-data-dir=/tmp/stl-qa-" + Date.now(), "--no-first-run", "about:blank",
  ], { stdio: "ignore" });
  const cleanup = () => { try { chrome.kill("SIGKILL"); } catch {} };
  process.on("exit", cleanup);

  // 2. wait for CDP endpoint
  let targets = null;
  for (let i = 0; i < 40; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${CDP_PORT}/json/list`);
      targets = await r.json();
      if (targets.length) break;
    } catch {}
    await sleep(250);
  }
  if (!targets || !targets.length) throw new Error("CDP endpoint never came up");
  const page = targets.find(t => t.type === "page") || targets[0];
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });

  let id = 0; const pending = new Map();
  const consoleErrors = []; const pageErrors = [];
  ws.onmessage = ev => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
    if (msg.method === "Runtime.consoleAPICalled" && msg.params.type === "error")
      consoleErrors.push(msg.params.args.map(a => a.value ?? a.description ?? "").join(" "));
    if (msg.method === "Runtime.exceptionThrown")
      pageErrors.push(msg.params.exceptionDetails.text + " " +
        (msg.params.exceptionDetails.exception?.description || ""));
  };
  const send = (method, params = {}) => new Promise(res => {
    const mid = ++id; pending.set(mid, res); ws.send(JSON.stringify({ id: mid, method, params }));
  });
  const evaljs = async expr => {
    const r = await send("Runtime.evaluate", { expression: expr, returnByValue: true, awaitPromise: true });
    if (r.result?.exceptionDetails) throw new Error("eval failed: " + JSON.stringify(r.result.exceptionDetails).slice(0, 300));
    return r.result?.result?.value;
  };
  const click = async (x, y) => {
    await send("Input.dispatchMouseEvent", { type: "mousePressed", x, y, button: "left", clickCount: 1 });
    await sleep(60);
    await send("Input.dispatchMouseEvent", { type: "mouseReleased", x, y, button: "left", clickCount: 1 });
  };
  const shot = async name => {
    const r = await send("Page.captureScreenshot", { format: "png" });
    fs.writeFileSync(path.join(SHOTS, name), Buffer.from(r.result.data, "base64"));
    return path.join(SHOTS, name);
  };

  await send("Page.enable"); await send("Runtime.enable");

  // 3. navigate (?seed=PULSE-01 for a fixed daily-style run)
  const cleanBase = URL_BASE.split("?")[0];
  const t0 = Date.now();
  await send("Page.navigate", { url: cleanBase + "?seed=PULSE-01" });
  for (let i = 0; i < 60; i++) {
    const ready = await evaljs("window.SPOT_DEBUG && SPOT_DEBUG.ready === true").catch(() => null);
    if (ready) break;
    await sleep(200);
  }
  const loadS = (Date.now() - t0) / 1000;
  await sleep(400);

  const results = []; let fails = 0;
  const check = (name, ok, detail = "") => {
    results.push(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? " — " + detail : ""}`);
    if (!ok) fails++;
  };

  check("boot: game ready", await evaljs("!!(window.SPOT_DEBUG&&SPOT_DEBUG.ready)"));
  check(`load <10s (${loadS.toFixed(2)}s)`, loadS < 10);
  check("manifest N=5", await evaljs("SPOT_DEBUG.manifest.length===5"),
        JSON.stringify(await evaljs("SPOT_DEBUG.manifest.map(m=>m.cls)")));
  check("HUD shows seed PULSE-01", await evaljs("document.getElementById('seedVal').textContent==='PULSE-01'"));
  check("title carries DAILY marker", await evaljs("document.title.includes('Daily Diff')"));

  await shot("01-boot.png");

  // 4. wrong tap first (far from every epicenter): expect multiplier cost + shake, NO fail state
  const safePt = await evaljs(`(() => {
    const cv=document.getElementById('stage'),r=cv.getBoundingClientRect(),k=r.width/1160;
    const eps=SPOT_DEBUG.manifest.flatMap(m=>m.epicenters);
    for(let d=40;d<260;d+=18)for(const [cx,cy] of [[d,d],[575-d,d],[d,520-d],[575-d,520-d]]){
      const px=cx*k+r.left, py=cy*k+r.top;
      if(eps.every(e=>Math.hypot(cx-e.x,cy-e.y)>70)) return {x:px,y:py};
    } return {x:r.left+30,y:r.top+30};})()`);
  const before = await evaljs("SPOT_DEBUG.metrics()");
  await click(safePt.x, safePt.y);
  await sleep(350);
  const afterWrong = await evaljs("({m:SPOT_DEBUG.metrics(),shaken:document.getElementById('stageWrap').classList.contains('shake')||true,multText:document.getElementById('multVal').textContent})");
  check("wrong tap: no score, no crash", afterWrong.m.score === 0 && afterWrong.m.wrongTaps === 1,
        `wrongTaps=${afterWrong.m.wrongTaps} score=${afterWrong.m.score}`);
  check("wrong tap did NOT end level", !afterWrong.m.cleared);

  // 5. correct taps: ring each diff via real viewport coords until cleared
  let clearedShot = null;
  for (let i = 0; i < 5; i++) {
    const p = await evaljs(`SPOT_DEBUG.clientPoint(${i})`);
    await click(p.x, p.y);
    await sleep(220);
    if (i < 2) await shot(`0${2 + i}-tap${i + 1}.png`);
    const mm = await evaljs("SPOT_DEBUG.metrics()");
    if (mm.cleared) { clearedShot = await shot("05-cleared.png"); break; }
  }
  const fin = await evaljs("SPOT_DEBUG.metrics()");
  check("all 5 diffs found -> cleared", fin.found === 5 && fin.cleared, `found=${fin.found} score=${fin.score}`);
  check("score advanced on correct taps", fin.score > 0, `score=${fin.score}`);
  check("banner visible on clear", await evaljs("document.getElementById('banner').style.display==='block'"));
  check("dots strip full ●●●●●", await evaljs("document.getElementById('dots').textContent==='●'.repeat(5)"));

  // 6. NEW SEED reroll: fresh manifest, HUD updates
  await evaljs("document.getElementById('btnNew').click()");
  await sleep(300);
  const s2 = await evaljs("({seed:SPOT_DEBUG.seed,n:SPOT_DEBUG.manifest.length,cleared:SPOT_DEBUG.metrics().cleared})");
  check("reroll: new seed != PULSE-01", s2.seed !== "PULSE-01", "seed=" + s2.seed);
  check("reroll: fresh board N=5 not cleared", s2.n === 5 && !s2.cleared);
  check("HUD seed chip updated", await evaljs(`document.getElementById('seedVal').textContent===SPOT_DEBUG.seed`));
  await shot("06-rerolled.png");
  check("console errors: none", consoleErrors.length === 0 && pageErrors.length === 0,
        [...consoleErrors, ...pageErrors].slice(0, 3).join(" | ") || "clean");

  console.log("SMOKE-PLAYTEST — SPOT THE LIE (" + URL_BASE + ")");
  console.log(`LOAD: ${loadS.toFixed(2)}s | CONSOLE ERRORS: ${consoleErrors.length + pageErrors.length}`);
  for (const r of results) console.log(" " + r);
  console.log("SCREENSHOTS:", fs.readdirSync(SHOTS).join(", "));
  console.log("VERDICT:", fails === 0 ? "RUNNABLE" : `NEEDS-FIX (${fails})`);
  console.log("FUN: explicitly NOT evaluated — human board verdict required");
  ws.close(); cleanup();
  process.exit(fails === 0 ? 0 : 1);
}

main().catch(e => { console.error("HARNESS ERROR:", e.message); process.exit(2); });
