# DECISIONS.md — t_0915877f SPOT THE LIE W1 feeler (append-only)

1. Repo = this workspace; single-file `index.html` at root so GH Pages serves it at repo URL with zero config.
2. Title locked: "SPOT THE LIE — Daily Diff" (C1: procedural/DAILY marker readable at thumbnail+title).
3. RNG: mulberry32 seeded PRNG; scene-graph generated from seed, rendered twice — left half pristine, right half mutated. Generator IS the answer key (manifest printed to console).
4. Mutation classes: add / remove / flip / swap-position / resize. Recolor deliberately NOT implemented as a class at all → accessibility pin satisfied by construction, not by sampling discipline.
5. Salience floor ACTIVE in greybox per C3: each mutation must move ≥FLOOR pixels of shape boundary (min over affected shapes' edge travel) AND land ≥MIN_CLEAR px away from every other mutation's epicenter (anti-cluster); reject-and-regenerate below-floor mutations, max 40 attempts then re-seed scene. Floor values logged per accepted mutation.
6. N=5 diffs at feeler scale (spec). Scene = ~14 greybox shapes (rects/circles/tri-ish rects) on muted ground, decoys by density.
7. Tap-diff: correct tap rings green + scores (base 100 x multiplier, multiplier decays with elapsed time — scoring-not-survival, NO hard-fail clock anywhere); wrong tap shakes + costs 50% of current multiplier only, never time. Streak protection: first wrong tap after a streak ≥2 does not break the chain ("CHAIN GUARD" tag shown).
8. Seed string visible in HUD strip from first paint + "NEW SEED" reroll button (daily-identity groundwork; also lets pulse testers sample across seeds fast). Seed accepts URL ?seed= for shareable daily-style runs.
9. Diff manifest printed to console on generate = answer key (spec mandate).
10. No tutorial/art/sound/menu per spec scope cut; one WebAudio debug blip on correct tap only (debug tone allowed).

--- run 96 (verification + delivery; prior run 93 built the game but exited without a terminal call) ---

11. Run 93's index.html passed static spec audit on re-read; run 96 VERIFIED it instead of rebuilding — no code changes to the game were needed.
12. Verification stack is dependency-free (no Playwright MCP / pip playwright on box): (a) `node harness.js` — Node VM extracts the generator and stress-tests 2000 seeds (class legality incl. recolor-absence, floor integrity, 66px anti-cluster, determinism, variety: ALL PASS); (b) `node playtest.js` — raw-CDP over Node22 native WebSocket driving a DEDICATED headless chromium (skill pitfall #9): boot/load/wrong-tap/5-tap-clear/reroll = 15/15 PASS locally, then re-run against the LIVE Pages URL = 15/15 PASS. Gotcha: CDP target[0] was the snap-extension background_page, not the tab — select type==="page".
13. Deploy: sxaad69/spot-the-lie (public, master @ root, legacy Pages source). curl-verified https://sxaad69.github.io/spot-the-lie/ = HTTP 200 + exact title before any summary cited it (rule 14); pages status=built on first poll.
14. One live-run FAIL was a HARNESS bug (double ?seed= when STL_URL already carried a query string), not a game defect — fixed in playtest.js, disclosed here to keep the evidence honest. QA tools committed to the repo because README cites them; probe.js stays local (one-off debug).
