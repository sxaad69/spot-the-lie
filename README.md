# SPOT THE LIE — Daily Diff (W1 greybox feeler)

Procedural observation-diff: one seeded scene-graph rendered twice (ORIGINAL / THE LIE);
find the 5 structural differences. The generator IS the answer key — every puzzle is
regenerated from an 8-char seed, so a worldwide daily seed is a free mode later.
**Throwaway W1 feeler** (pinned rule 12): single-file HTML, no engine, no build step.
This prototype's code is never promoted; only the loop verdict carries forward.

**Maturity:** W1 pulse-gate feeler (board plays → KEEP/KILL).

## Play

https://sxaad69.github.io/spot-the-lie/

- `?seed=XXXX-XXXX` URL param for shareable runs (daily-seed groundwork).
- `NEW SEED` rerolls; `REPLAY THIS SEED` regenerates the identical board.
- The browser console prints the diff manifest — the machine-readable answer key.

## Gate conditions honored in the greybox

- **C1 daily identity:** title + badge carry "Daily Diff"; the seed string is a HUD element from first paint.
- **C2 scoring-not-survival:** the timer drains the score MULTIPLIER only. No hard-fail clock exists anywhere; time-out never ends a level. Wrong tap costs multiplier + has chain-guard streak protection.
- **C3 salience floor (generator-enforced):** mutations below the pixel edge-travel floor (scaled up in decoy-dense neighbourhoods) are rejected-and-regenerated, never shipped. Rejection log prints to console.
- **Accessibility pin:** recolor is not implemented as a mutation class at all — every diff is structural {add, remove, flip, swap-position, resize}.

## Verification (evidence)

- `harness.js` — generator stress test: 2000 seeds × 5 diffs, class legality, floor integrity,
  anti-cluster separation, determinism, puzzle variety. Run: `node harness.js`.
- `playtest.js` — real-browser CDP playthrough (dedicated headless chromium): boot, load <10s,
  wrong-tap penalty path, all 5 diffs tapped via real input events, clear banner, reroll.
  Run: `STL_URL=<url> node playtest.js`.

## Known limitations (by scope cut)

No tutorial, no art/themes (greybox shapes), no sound beyond debug blip, no mode menu,
no save, no monetization UI. Full build (Godot 2D, AI-painted scenes) fires only after
a human pulse KEEP verdict.
