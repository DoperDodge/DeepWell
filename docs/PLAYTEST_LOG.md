# Playtest log

Protocol per PLAN §18.2: play the exported build (not the editor) at each
phase boundary and answer all six questions — question 6 (the most boring
60 seconds) matters more than question 5 (the scariest moment).

## 2026-07-27 — Phase 3 slice, automated headless pass

Environment limitation: this phase was built and verified in a headless
container; human playtesting was not possible. What was verified instead:

1. **Crashes:** none across `--validate` (60-seed generation soak,
   determinism check) and `--smoke` (full loop: doors, loot, flashlight,
   documents, 914 upgrade, save round-trip, SCP-173 hunt-kill, ironman
   delete, corpse persistence) — both in-editor and inside the exported
   Linux binary.
2. **Framerate:** not measurable headless. Budget risks flagged for the
   first human session: per-cell box meshes (~2k draw calls) and per-frame
   gaze evaluation. Both have planned mitigations (MultiMesh merge;
   30 Hz gaze tick) if the profiler confirms.
3. **Unfair deaths:** the known risk is 173's hearing-based wake
   (`loudness > 0.3`) triggering before the player has seen it — first
   human session must confirm the scripted chamber encounter reads as the
   "visible, learnable warning" the plan requires.
4. **Getting lost:** wayfinding signs point toward the stairwell from ~10
   corridor cells; untested by a human.
5. **Scariest moment (expected):** first unobserved 173 step after the
   player learns the freeze rule.
6. **Most boring 60 s (expected):** corridor walking between offices when
   no anomaly pressure is active; Director near-miss scheduling (§12.4)
   is the lever to tune first.

**Action for next session with a display:** 30-minute exported-build session
answering all six questions for real, plus FPS capture at 1080p.
