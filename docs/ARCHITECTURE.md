# Architecture

How the implementation maps to PLAN.md, and where (and why) it deviates.

## System layout

```
EventBus (signal hub) ── every cross-system message
RNG ── seeded streams; one per subsystem; determinism is load-bearing
GameState ── run data: seed, floor, clearance, journal, telemetry, grid ref
TimeManager ── game clock (1 h = 90 s) + staggered tick scheduler
FacilityState ── run diffs (doors/containers/pickups) + PERSISTENT SITE FILE
LightProbe ── "how lit is this point" with 0.2 s cache (drives gaze + sanity)
Director ── tension, rest beats after scares, anti-camping pressure
AudioManager ── bus setup + fully procedural sound synthesis
SaveManager ── versioned JSON run saves; ironman deletes on death
```

Systems communicate only through `EventBus` signals (PLAN §5.2). The one
sanctioned piece of shared state is `GameState.grid` — a `FacilityGrid` is
data, not a system: pathfinding, noise propagation, and wall geometry all
read the same cell/door topology, which is what keeps physics, AI, and
audio mutually consistent.

## The grid

`FacilityGrid` holds 4 m cells (SOLID / ROOM / CORRIDOR), room ownership,
and **edge doors**. Two A* graphs are maintained: `_nav` (closed doors
block — what a walking anomaly can traverse) and `_open` (doors ignored —
what sound passes through, attenuated ×0.4 per closed door, ×0.05 per blast
door). An edge between adjacent walkable cells is passable iff same room,
both corridor, or a door — `RoomBuilder` erects walls from the *same
predicate*, so a wall you can see is always a wall for AI and for sound.

## Generation (PLAN §6.3 adapted)

Mandatory rooms place first (exit first, far from spawn), weighted filler
rooms follow, corridors connect via MST + ~22% extra loop edges (dead ends
are unfair deaths), then completability is asserted with a clearance-aware
BFS: spawn →(L0) L1 card →(L1) keycard office →(L2) stairwell. Failure
reseeds (30 attempts) and finally falls back to a known-good static layout.
Alternate progression: SCP-914 upgrades keycards (Fine = +1 level), corpses
can carry cards, and some doors spawn powered-down (crowbar path).

## Deviations from PLAN.md, and why

This project was built in a headless environment with no Blender, no editor
GUI, and a no-binary-assets constraint. Four consequences:

1. **Runtime-generated geometry instead of `.glb` kits (§3.3, §13.3).**
   Rooms are `RoomDef` resources realized by `room_builder.gd` from
   primitive meshes + shared materials. The §3.3 Blender generators remain
   the intended upgrade path — swap `_dress_*` implementations for kit
   scenes without touching the generator.
2. **Cell A* instead of baked navmesh (§12.3).** Grid A* is deterministic,
   rebake-free (door state flips edges instantly), and doubles as the noise
   graph. SCP-173's 4 m teleport-step maps 1:1 onto 4 m cells.
3. **Procedural audio (§14).** ~30 sounds are synthesized at startup in
   `audio_manager.gd` (noise, sines, one-pole filters, envelopes). Zero
   licensing surface. Replace any entry in `_build_library()` with a CC0
   sample later — the play API doesn't change.
4. **Scenes built in code, not `.tscn` (§4).** With no editor available,
   text-authored deep `.tscn` files are write-only. The spirit of the rule
   (logic out of scenes, content out of code) is kept: content lives in
   `data/`, logic in `src/`, and `scenes/main.tscn` is the only scene file.

## Perception

- `PlayerGaze` returns observation **strength** (frustum → attention cone →
  occlusion ray excluding the target's own body → light level → distance).
  SCP-173 freezes above 0.55 and *slows* below it — peripheral vision
  half-holds it.
- Blinking zeroes observation for its duration. Suppression (hold RMB)
  builds pressure toward a longer forced blink. Fatigue, panic, and low
  sanity raise blink rate — the survival sim and the horror mechanic are
  the same system.
- Noise events run through `FacilityGrid.effective_loudness` — the same
  path distance an anomaly would walk, so what you hear maps to what can
  reach you.

## Persistence

Three layers, deliberately distinct:
- **Settings** (`user://settings.cfg`) — machine-local preferences.
- **Run save** (`user://saves/run.json`, versioned) — layout regenerates
  from the seed; only diffs are stored (door states, container contents,
  removed pickups, entity states, player state). Ironman deletes on death.
- **Site file** (`user://sites/site_<seed>.json`) — survives death by
  design: corpse records (with full inventory), D-Class designation
  counter, incident log, breach registry. This is PLAN §16.3/§20.1: the
  world persists, and dying is worldbuilding.
