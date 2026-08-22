# Prototype Brief — SPOT THE LIE (W1 feeler)

QUESTION:     Does seeded procedural spot-the-diff land the gotcha-flick moment, with a
              spot-rate in the 40-80% band across seeds (pulse gate)?
CORE VERB:    Tap the difference between two halves of one procedural scene.
THROWAWAY?:   yes — single-file HTML greybox, never promoted (pinned rule 12).
TIMEBOX:      ~15-20 min of build work per spec W1 budget.
KEEP IF:      human pulse verdict KEEP (spot-rate lands in 40-80% band across seeds,
              gotcha-flick moment lands). Board decides; I ship evidence.
KILL IF:      spot-rate trivial (<40%) or impossible (>80%) across seeds → KILL;
              cluster incumbent ships daily-procedural before launch → re-gate.

# Gate conditions encoded
- C1: title carries DAILY/procedural marker ("SPOT THE LIE — Daily Diff"); seed string is a
  visible UI element from first paint.
- C2: timer drains a score MULTIPLIER only. No hard-fail clock anywhere; time-out never ends
  a level. Wrong tap costs multiplier + streak protection ("chain guard") on first miss.
- C3: salience floor ACTIVE in greybox — generator rejects-and-regenerates any mutation whose
  pixel-distance falls below floor vs local decoy density. Below-floor diffs unshippable by
  construction.
- Accessibility pin: recolor is NEVER a mutation class at all in this greybox — structural
  classes {add, remove, flip, swap-position, resize} carry every diff.

# Non-goals (scope cut per spec)
No tutorial, no art/themes, no mode menu, no sound beyond debug tone, no multi-level flow
beyond seed-reroll button, no save, no monetization UI.
