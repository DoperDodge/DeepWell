# Data schemas

All content lives under `data/` (PLAN §5.3). Adding content means adding a
file here — never editing engine code. `tools/check.sh` validates all of it.

## `data/items/*.tres` — `ItemDefinition`

| Field | Notes |
|---|---|
| `id` | unique StringName; the save format stores these |
| `display_name`, `description` | player-facing |
| `weight_kg`, `max_stack` | inventory is weight-based |
| `world_shape` | `box` `cylinder` `sphere` `card` `paper` — pickup visual |
| `world_color`, `world_size` | pickup visual |
| `categories` | `food` `drink` `medical` `keycard` `tool` `light` `battery` `material` `document` `anomalous` `comfort` |
| `use_behavior` | `consume` `medical` `battery` `flashlight` `read` (dispatch in `item_behaviors.gd`) |
| `behavior_params` | e.g. `{"medical_kind": "bandage", "power": 1.0}`; kinds: `bandage` `suture` `splint` `disinfect` `painkiller` `panacea` |
| `clearance_level` | ≥0 makes it a keycard |
| `hunger_restore` … `sickness_risk` | consumable effects |
| `upgrade_result` / `refine_result` / `downgrade_result` | SCP-914 Fine / Very Fine / Rough-Coarse outputs |

## `data/moodles/*.tres` — `MoodleDefinition`

`stat` names resolve through `Player.get_stat`: needs (`hunger`, `thirst`,
`fatigue`, `boredom`, `unhappiness`, `stress`, `panic`) plus derived
(`pain`, `bleeding`, `sickness`, `infection`, `injury`, `blood_loss`,
`winded`, `encumbrance`, `sanity_low`). `thresholds` are four ascending
values marking severity 1–4; `labels` name each severity.

## `data/room_prefabs/*.tres` — `RoomDef`

`size_w/size_h` in 4 m cells. `style` picks the dressing routine in
`room_builder.gd` (`office`, `storage`, `break_room`, `containment_cell`,
`lab`, `checkpoint`, `machine_room`, `empty`). `special` marks mandatory
singletons: `spawn`, `stairwell`, `keycard_office`, `scp_173_chamber`,
`scp_914`. `door_clearance` locks every door of the room;
`powered_down_chance` converts some to the crowbar path. Dressing knobs:
`containers_min/max`, `loot_table`, `documents_min/max`, `light_color`,
`broken_light_chance`, `corpse_chance`.

## `data/floors/floor_N.tres` — `FloorDef`

Grid size, `target_rooms`, `extra_link_fraction` (corridor loops),
`ambient_light`, `ambience_sound`, corridor light spacing/breakage,
`scp_spawns` (script names under `src/scps/`), `exit_clearance`,
`pa_lines`.

## `data/loot_tables/*.tres` — `LootTable`

`rolls_min/max`, `empty_chance` (scarcity), entries
`{"item": &"id", "weight": w, "min": n, "max": m}`. Rolls are seeded from
`(run seed, container id)` — a container's contents are fixed the moment
the run starts, no matter when it is opened.

## `data/documents/*.json`

```json
{
  "id": "doc_x", "title": "…", "doc_type": "memo", "found_on_floor": 3,
  "body": [
    {"clearance": 0, "text": "readable at any clearance "},
    {"clearance": 2, "text": "the truth", "redacted_as": "[REDACTED]"},
    {"clearance": 4, "text": "the whole truth", "redacted_as": ""}
  ]
}
```

Spans above the player's clearance render `redacted_as` as a black bar; an
empty `redacted_as` hides the span *entirely* (you can't see the shape of
what you're missing). `found_on_floor: -1` keeps a document out of the
floor's random pool (used for scripted placements like SCP-1048's
drawings). Author everything at full L5 detail, then redact down — story
gating and keycard gating are one axis (PLAN §8.1).

## `data/attribution.json`

`[{"designation", "url", "authors"}]` — feeds the in-game Credits &
Licensing screen. Every SCP referenced anywhere in `data/` must appear here
and in `docs/ATTRIBUTION.md`, in the same commit.

## Save formats (versioned)

- Run save `user://saves/run.json` — `version` 1; layout regenerates from
  `seed`, diffs apply on top. Write a migration in `save_manager.gd` before
  ever bumping the version.
- Site file `user://sites/site_<seedcode>.json` — `version` 1; corpse
  records `{floor, cell, cause, designation, items[]}`, incident log,
  breach list, designation counter.
