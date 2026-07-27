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

## 2026-07-27 — v0.5 four-floor build, automated headless pass

1. **Crashes:** none. `--validate` (15 seeds × 4 floors, determinism) and
   `--smoke` (complete run: intake → four floors → ending, plus the risen
   pestilent corpse and a 173 kill regression) pass in-editor and in the
   exported binary.
2. **Balance risks flagged for human play:** SCP-966's rush trigger
   (fatigue > 65 or standing still 6 s) may need a first-encounter grace;
   SCP-049's door-opening plus 049-2 pack pressure on Floor 4 is
   deliberately the hardest beat in the game and needs a fairness read;
   Pestilence stage 1 is symptomless by design — confirm players connect
   the fever moodle to the bite before stage 3 makes it obvious.
3. **Most boring 60 s (expected):** Floor 1 by design — it is the quiet
   contrast floor. Confirm it reads as dread, not filler.

## 2026-07-27 — v0.5.1 hotfix: main menu off-screen on Windows

First real-hardware report: on Windows 11 the whole main-menu column
rendered up-left of the viewport (title and BEGIN INTAKE invisible).
Cause: UI built as top-level Controls under the CanvasLayer using
"anchor preset + manual position offset" — laid out against a zero-sized
parent on a real window, a failure headless layout never reproduced.
Fix: container-driven layout everywhere (CenterContainer/MarginContainer,
no manual offsets), `canvas_items` stretch with a 1600x900 design canvas,
a self-healing viewport pin for UI roots (UILayout), and a new headless
UI-geometry probe (`--uiprobe`) asserting every element lands inside the
viewport at two window sizes — now part of tools/check.sh and the
release workflow gates.

## 2026-07-27 — v0.5.2: doors sealed, isometric conversion

Two field reports from the Windows build. First: every door stood
perpendicular to its own wall, leaving the opening gaping — the rotation
condition keyed on the wrong axis (Y-adjacent cells were rotated instead
of X-adjacent). Fixed, and `--validate` now asserts, for all 67 doors
across the four floors, that the panel's thin axis lies along the edge it
seals and its slide axis does not pass through the wall.

Second, and larger: the brief was always Project Zomboid, and the game
had been built first-person. Converted to a fixed-yaw isometric follow
camera with a visible character who faces the mouse, screen-relative
movement, cursor-driven interaction, and PZ-style wall cutaway with no
ceilings.

Balance consequence worth watching in the next human session: the gaze
light curve was rebalanced (a 0.2 floor above pitch-dark) because the old
curve gave only a 0.09 hold in ambient-lit corridors, meaning SCP-173 was
effectively unfreezable away from a light fixture. It should now creep in
gloom and freeze hard under a flashlight — confirm that reads as fair.

Also fixed: a headless tool script that failed to compile used to fall
through to the main menu and hang CI until timeout; `main.gd` now aborts
with a diagnostic instead.
