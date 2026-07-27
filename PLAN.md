# PROJECT DEEPWELL — Master Implementation Plan

**Codename:** DEEPWELL
**Setting:** SCP Foundation Site-104 (original site designation — deliberately non-canon so no existing lore constrains the layout)
**Genre:** First-person survival horror / hardcore survival sim
**Platform:** Windows 64-bit, distributed as a standalone `.exe`
**Engine:** Godot 4.5+ (Forward+ renderer)
**License:** CC BY-SA 3.0 (mandatory — see §2)

---

## §0 — HOW TO USE THIS DOCUMENT

**This document is the single source of truth.** It is written to be handed to an AI implementation agent (Fable 5) and executed phase by phase.

### Rules for the implementing agent

1. **Work in phases (§20).** Do not attempt to build everything at once. Each phase has explicit acceptance criteria. A phase is not complete until the criteria pass *and* the game exports to a working `.exe`.
2. **This is NOT a web game.** Do not produce HTML, JavaScript, canvas rendering, or a browser build. The deliverable is a native Godot project that exports to a Windows executable. If you find yourself writing `<canvas>` or `index.html`, stop.
3. **No placeholder code.** Do not write `# TODO: implement combat`. If a system is out of scope for the current phase, stub it with a *working* minimal version (e.g. combat that deals fixed damage), not a comment.
4. **Every system is data-driven.** Content (SCPs, items, rooms, traits) lives in `.tres` resource files or JSON, never hardcoded in scripts. Adding a new SCP must not require editing engine code.
5. **Commit after every working increment.** Small commits, descriptive messages.
6. **Run the exporter at the end of every phase.** A phase that builds in-editor but fails export is a failed phase.
7. **Read §2 before writing a single line.** The licensing constraints are real and they change what art you are allowed to make.

### Reality check (read this, then proceed anyway)

This plan describes a game with the survival depth of Project Zomboid and the presentation of a modern horror title. For context: Project Zomboid has been in development since 2011 by a full studio. This is not a weekend project.

That is not a reason to shrink the vision — it is a reason to **sequence** it. The phase structure in §20 is designed so that:

- **Phase 3 produces a genuinely playable, genuinely scary game** — one floor, three SCPs, full survival loop, exported `.exe`.
- Everything after Phase 3 is additive. The game is never in a broken, unplayable state waiting for a big-bang integration.

Build Phase 3 first. Ship it to yourself. Play it. Then keep going. A finished small game beats an unfinished huge one, and the architecture here lets the small game grow into the huge one without rewrites.

---

## §1 — GAME IDENTITY

### One-line pitch

You are D-9341, a Class-D test subject in an SCP Foundation deep-storage site during a cascading containment failure. The only way out is down.

### The core loop

```
Spawn on Floor 1 (Entrance Zone) with nothing
   ↓
Explore → scavenge supplies, documents, tools
   ↓
Manage survival needs (hunger, thirst, fatigue, injury, sanity)
   ↓
Evade / outwit anomalies (you cannot win fights)
   ↓
Locate a keycard of sufficient clearance
   ↓
Unlock stairwell OR elevator to the next floor down
   ↓
Descend. Everything gets worse.
   ↓
Repeat across 8 floors → reach the bottom → escape (or don't)
```

### Design pillars

1. **The Foundation is scarier than the anomalies.** The bureaucracy that decided you were expendable is the real horror. Every document, intercom announcement, and corpse reinforces this.
2. **Attrition, not action.** You are a malnourished prisoner in a paper jumpsuit. There is no health bar regenerating between fights. A broken leg on Floor 4 is a death sentence on Floor 5.
3. **Knowledge is the real progression.** Skills level, yes — but the actual progression is *the player learning that 096 can't be outrun, that 939 hunts by sound, that 106 comes through walls.* Death teaches.
4. **Descent as escalation.** Each floor is measurably worse: darker, more damaged, higher-class anomalies, fewer supplies, less signage.
5. **No cheap jumpscares.** Dread is built from audio, sightlines, and the knowledge that something is loose. If a scare requires a loud noise sting to land, it isn't a scare.

### Tone reference

`SCP – Containment Breach` (structure) × `Project Zomboid` (systemic depth) × `Alien: Isolation` (AI dread, no combat solution) × `Barotrauma` (systems interacting badly on purpose)

---

## §2 — LEGAL & LICENSING (NON-NEGOTIABLE)

**Read this section fully. It constrains art, code, and distribution.**

### 2.1 The SCP Wiki license

All SCP Foundation content is licensed **CC BY-SA 3.0** (Creative Commons Attribution-ShareAlike 3.0). The *ShareAlike* clause is viral. This means:

> **This entire game must be released under CC BY-SA 3.0.**

Consequences you must accept:

- Anyone who obtains a copy may legally redistribute it, for free, to anyone.
- Anyone may make derivative works from it (mods, sequels, reskins) and sell them, provided they attribute you and license their work the same way.
- You cannot make the game proprietary, closed-source-restrictive, or "all rights reserved."

This is fine — it's the same license under which `SCP – Containment Breach`, `SCP: Blackout`, and every other SCP game ships. But it must be a conscious decision, not an accident.

### 2.2 Required attribution

Ship a `LICENSE.md` and an in-game **Credits & Licensing** screen containing:

```
Content relating to the SCP Foundation, including the SCP Foundation logo,
is licensed under Creative Commons Attribution-ShareAlike 3.0
(https://creativecommons.org/licenses/by-sa/3.0/)
and all concepts originate from https://scpwiki.com and its authors.

PROJECT DEEPWELL, being derived from this content, is hereby also released
under Creative Commons Attribution-ShareAlike 3.0.
```

Then list, per SCP used: the designation, the article URL, and the credited author(s). Pull author names from the article's page history / "rate this" byline. Maintain this in `docs/ATTRIBUTION.md` and generate the in-game screen from it.

### 2.3 ⚠️ THE SCP-173 TRAP — CRITICAL

**The text of SCP-173 is CC BY-SA. The image is not.**

The photograph long associated with SCP-173 depicts *Untitled 2004*, a sculpture by the Japanese artist **Izumi Kato**. Kato granted the wiki limited permission for non-commercial wiki use only. He never released the sculpture's likeness under any Creative Commons license, and it has since been removed from the wiki. **He still holds copyright.**

**Therefore:**

- ❌ Do **not** model SCP-173 to resemble Kato's sculpture. No painted face, no drip-marks, no rebar-and-rock silhouette copied from that photo.
- ✅ Design an **original** concrete-and-rebar humanoid figure from scratch. The *article text* describes it only as a sculpture of spray-painted concrete and rebar. That description is yours to interpret freely.
- Document the design as original in `docs/ATTRIBUTION.md`.

This same principle applies to **every** SCP with a well-known "official" image. Assume every image on the wiki is separately licensed from the text. **Use the text. Never copy the picture.** When in doubt, design original.

### 2.4 Third-party assets

Every asset must be license-compatible with a CC BY-SA 3.0 release. Maintain `docs/ASSET_LICENSES.md` with source URL, author, and license for every single imported file.

| Status | License | Notes |
|---|---|---|
| ✅ Safe | CC0 / Public Domain | Preferred. No obligations. |
| ✅ Safe | CC BY 3.0 / 4.0 | Attribution required. |
| ✅ Safe | CC BY-SA 3.0 | Same license, compatible. |
| ⚠️ Check | CC BY-SA 4.0 | One-way compatible *to* 4.0, not back to 3.0. Avoid mixing. |
| ❌ Forbidden | CC BY-**NC** (NonCommercial) | Incompatible with CC BY-SA. Never use. |
| ❌ Forbidden | CC BY-**ND** (NoDerivs) | Incompatible. Never use. |
| ❌ Forbidden | "Free for personal use" fonts/models | Not a real license. Never use. |

**Recommended CC0 sources:** Poly Haven (HDRIs, textures, models), ambientCG (PBR materials), Kenney.nl (models, audio, UI), Quaternius (models), Freesound (filter to CC0 explicitly — Freesound hosts mixed licenses), OpenGameArt (filter to CC0/CC-BY).

**Godot itself** is MIT licensed and imposes no restrictions, no royalties, and no revenue share. Include Godot's copyright notice in the credits (`Godot Engine © 2007-present Juan Linietsky, Ariel Manzur and contributors`).

### 2.5 Trademark note

The "SCP Foundation" name and logo were trademarked in the Russian Federation by a third party (Andrey Duksin) in a widely-condemned action. The situation has largely been resolved in the community's favor, but as a precaution do not specifically target distribution to the Russian Federation / Eurasian Customs Union. This is not a concern for personal use.

---

## §3 — TECHNOLOGY STACK

### 3.1 Engine: Godot 4.5+ — and why not Unreal

This decision is deliberate and should not be revisited.

| Factor | Godot 4 | Unreal 5 | Unity 6 |
|---|---|---|---|
| **AI-authorable project files** | ✅ `.tscn`/`.tres` are **plain text** | ❌ `.uasset` are **binary blobs** | ⚠️ YAML, semi-readable |
| Scripting | GDScript (Python-like) + C# | C++ / Blueprints (binary) | C# |
| `.exe` export | One click, built in | Yes, heavy toolchain | Yes |
| Editor VRAM cost | Low (~1-2 GB) | Very high (Nanite/Lumen) | Medium |
| License / royalties | MIT, zero | 5% over $1M | Per-seat tiers |
| Install size | ~120 MB | ~100+ GB | ~30 GB |

**The decisive factor is the first row.** Unreal stores scenes, materials, and blueprints as binary `.uasset` files. An AI agent physically cannot write those with a text editor — every level, every material, every blueprint would require a human in the Unreal editor doing it by hand. Godot's scenes and resources are human-readable text that an agent can author, diff, and version-control directly.

Secondary factors that also favor Godot here:
- **GDScript is Python-like.** The developer already knows Python; the learning curve is days, not months.
- **Target hardware is an RTX 3070 Ti (8 GB VRAM).** Godot 4 Forward+ with SDFGI, SSIL, and volumetric fog runs comfortably in that budget. Unreal 5 with Nanite + Lumen would make the *editor* miserable on 8 GB, before the game even runs.

**Use C# only for measured hot paths** (pathfinding, large-scale physics queries) via Godot's `.NET` build, and only after profiling proves GDScript is the bottleneck. Do not start in C#.

### 3.2 Full stack

| Layer | Tool | Notes |
|---|---|---|
| Engine | **Godot 4.5+ (.NET build)** | Forward+ renderer, Vulkan |
| Primary language | **GDScript** | 90%+ of code |
| Hot-path language | **C#** | Only where profiled as necessary |
| 3D modeling | **Blender 4.x** | Free; **scriptable via Python** — the agent can generate models programmatically |
| Model exchange | **glTF 2.0 (`.glb`)** | Godot's best-supported format. Not FBX. |
| Textures | **ambientCG / Poly Haven (CC0)** | PBR: albedo, normal, roughness, metallic, AO |
| Audio editing | **Audacity** or **ffmpeg** | ffmpeg is scriptable |
| Audio format | `.ogg` (music/ambience), `.wav` (short SFX) | |
| Version control | **Git + GitHub** | `.gitattributes` with Git LFS for binaries |
| Fonts | **Inter**, **JetBrains Mono**, **Share Tech Mono** (all OFL) | OFL is CC BY-SA compatible |

### 3.3 Blender scripting — the art force multiplier

Because Blender is fully scriptable in Python, the implementing agent should **generate geometry with scripts rather than hand-modeling**:

```python
# tools/blender/gen_corridor_kit.py — run headless:
#   blender --background --python tools/blender/gen_corridor_kit.py
import bpy, bmesh, math

WALL_W, WALL_H, WALL_T = 4.0, 3.2, 0.2   # metric, matches Godot 1 unit = 1 m

def make_wall_panel(name, width=WALL_W, height=WALL_H, thickness=WALL_T):
    mesh = bpy.data.meshes.new(name)
    obj  = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(width, thickness, height),
                    verts=bm.verts)
    bm.to_mesh(mesh); bm.free()
    return obj

# ... generate the full modular kit, then:
bpy.ops.export_scene.gltf(filepath="assets/models/kits/corridor_kit.glb",
                          export_format='GLB')
```

This is how you get a consistent, correctly-scaled modular kit without an artist. Store all generators in `tools/blender/` and treat them as source code.

### 3.4 Units and conventions

- **1 Godot unit = 1 meter.** Never deviate.
- Player capsule: 0.4 m radius, 1.8 m height. Eye height 1.65 m. Crouched height 1.1 m.
- Standard corridor: 3.0 m wide × 3.2 m ceiling.
- Standard door frame: 1.2 m × 2.4 m. Blast door: 3.0 m × 3.0 m.
- Standard containment chamber: 5 m × 5 m × 5 m (matches the canonical SCP-096 cell).
- Grid snap for level assembly: **0.5 m**.
- Y-up, -Z forward (Godot default).

---

## §4 — REPOSITORY STRUCTURE

Create exactly this structure. Do not improvise alternate layouts.

```
deepwell/
├── PLAN.md                          # this document
├── README.md
├── LICENSE.md                       # CC BY-SA 3.0 full text
├── .gitignore                       # Godot: .godot/, *.import cache, export/
├── .gitattributes                   # Git LFS for *.glb, *.png, *.ogg, *.wav
├── project.godot
├── export_presets.cfg               # committed — defines the .exe build
│
├── docs/
│   ├── ATTRIBUTION.md               # per-SCP author credits (LEGALLY REQUIRED)
│   ├── ASSET_LICENSES.md            # every third-party file + license
│   ├── ARCHITECTURE.md              # system diagrams, signal flow
│   ├── DATA_SCHEMAS.md              # .tres resource field reference
│   └── PLAYTEST_LOG.md              # findings from each phase
│
├── src/                             # ALL GDScript. No scripts outside this tree.
│   ├── autoload/                    # singletons (see §5.1)
│   │   ├── game_state.gd
│   │   ├── event_bus.gd
│   │   ├── save_manager.gd
│   │   ├── director.gd
│   │   ├── audio_manager.gd
│   │   ├── time_manager.gd
│   │   └── facility_state.gd
│   ├── player/
│   │   ├── player.gd
│   │   ├── player_movement.gd
│   │   ├── player_camera.gd
│   │   ├── player_interaction.gd
│   │   ├── player_gaze.gd           # §9 — critical
│   │   └── player_noise_emitter.gd
│   ├── survival/                    # §11 — the Project Zomboid layer
│   │   ├── needs_component.gd
│   │   ├── health_component.gd
│   │   ├── body_part.gd
│   │   ├── moodle_system.gd
│   │   ├── infection_system.gd
│   │   ├── sanity_system.gd
│   │   ├── temperature_system.gd
│   │   └── nutrition_system.gd
│   ├── skills/
│   │   ├── skill_system.gd
│   │   ├── trait_system.gd
│   │   └── xp_multipliers.gd
│   ├── inventory/
│   │   ├── inventory.gd
│   │   ├── container.gd
│   │   ├── equipment_slots.gd
│   │   └── crafting_system.gd
│   ├── items/
│   │   ├── item_instance.gd
│   │   ├── item_pickup.gd
│   │   └── behaviors/               # one script per active-use behavior
│   ├── scps/
│   │   ├── scp_base.gd              # abstract base — all anomalies extend
│   │   ├── scp_173.gd
│   │   ├── scp_096.gd
│   │   ├── scp_106.gd
│   │   ├── scp_049.gd
│   │   ├── scp_049_2.gd
│   │   ├── scp_939.gd
│   │   ├── scp_079.gd
│   │   ├── scp_966.gd
│   │   ├── scp_035.gd
│   │   └── machines/
│   │       ├── scp_914.gd
│   │       └── scp_294.gd
│   ├── npcs/
│   │   ├── npc_base.gd
│   │   ├── mtf_operative.gd
│   │   ├── site_guard.gd
│   │   ├── researcher.gd
│   │   └── class_d.gd
│   ├── ai/
│   │   ├── behavior_tree/           # BT node classes
│   │   ├── perception/
│   │   │   ├── sight_sense.gd
│   │   │   ├── hearing_sense.gd
│   │   │   └── noise_propagation.gd
│   │   └── navigation_helper.gd
│   ├── facility/
│   │   ├── floor_generator.gd       # §6
│   │   ├── room_placer.gd
│   │   ├── corridor_weaver.gd
│   │   ├── loot_distributor.gd
│   │   ├── door.gd
│   │   ├── keycard_reader.gd
│   │   ├── elevator.gd
│   │   ├── power_grid.gd
│   │   └── ventilation.gd
│   ├── ui/
│   │   ├── hud/
│   │   ├── inventory_ui/
│   │   ├── document_viewer/
│   │   ├── menus/
│   │   └── character_creation/
│   └── util/
│       ├── rng.gd                   # seeded, deterministic
│       ├── math_ext.gd
│       └── debug_overlay.gd
│
├── data/                            # ALL CONTENT. Text/`.tres` only. No logic.
│   ├── scps/            *.tres      # SCPDefinition resources
│   ├── items/           *.tres      # ItemDefinition resources
│   ├── recipes/         *.tres
│   ├── traits/          *.tres
│   ├── occupations/     *.tres
│   ├── skills/          *.tres
│   ├── moodles/         *.tres
│   ├── room_prefabs/    *.tres      # room metadata (tags, connectors, weight)
│   ├── loot_tables/     *.tres
│   ├── documents/       *.json      # in-game readable documents
│   └── floors/          *.tres      # per-floor generation params
│
├── scenes/                          # .tscn — presentation only
│   ├── main.tscn
│   ├── player/
│   ├── scps/
│   ├── npcs/
│   ├── rooms/                       # hand-built room prefabs
│   │   ├── entrance/
│   │   ├── admin/
│   │   ├── light_containment/
│   │   ├── research/
│   │   ├── heavy_containment/
│   │   ├── maintenance/
│   │   └── deep_storage/
│   ├── props/
│   └── ui/
│
├── assets/
│   ├── models/
│   │   ├── kits/                    # modular building kits (.glb)
│   │   ├── props/
│   │   ├── characters/
│   │   └── items/
│   ├── materials/       *.tres
│   ├── textures/
│   ├── audio/
│   │   ├── sfx/
│   │   ├── ambience/
│   │   ├── voice/
│   │   └── music/
│   ├── fonts/
│   └── shaders/         *.gdshader
│
├── tools/
│   ├── blender/                     # Python geometry generators (§3.3)
│   ├── validate_data.gd             # schema validator, runs in CI
│   └── build.ps1                    # headless export → .exe
│
└── tests/
    ├── unit/                        # GUT framework
    └── integration/
```

---

## §5 — CORE ARCHITECTURE

### 5.1 Autoload singletons

Register these in `project.godot` in this order (order matters — later ones may depend on earlier):

| Autoload | Responsibility |
|---|---|
| `EventBus` | Global signal hub. **Systems never reference each other directly.** |
| `RNG` | Seeded deterministic random. All randomness goes through this. |
| `GameState` | Current run: floor, seed, player ref, difficulty settings |
| `TimeManager` | In-game clock, day/night (irrelevant underground but drives fatigue), tick scheduling |
| `FacilityState` | Power grid, alarm level, breach registry, door lock states, per-floor persistence |
| `Director` | Dynamic difficulty / anomaly scheduling (§13.4) |
| `AudioManager` | Bus routing, occlusion, 3D positioning, dynamic mix |
| `SaveManager` | Serialize/deserialize entire run state |

### 5.2 The EventBus pattern — mandatory

**Rule: no system may hold a direct reference to another system.** Everything communicates through `EventBus` signals. This is what makes the codebase extensible without cascading rewrites, and it's what lets an AI agent add a feature by touching two files instead of twenty.

```gdscript
# src/autoload/event_bus.gd
extends Node

# --- Player state ---
signal player_spawned(player: Node3D)
signal player_died(cause: String, floor_index: int, position: Vector3)
signal player_moved_floor(from_floor: int, to_floor: int)

# --- Perception (§9) ---
signal noise_emitted(position: Vector3, loudness: float, source: Node, tags: Array[String])
signal player_gaze_entered(target: Node3D)
signal player_gaze_exited(target: Node3D)
signal player_blinked()

# --- Survival (§11) ---
signal moodle_changed(moodle_id: StringName, level: int)
signal body_part_damaged(part: StringName, damage_type: StringName, amount: float)
signal infection_stage_changed(infection_id: StringName, stage: int)
signal sanity_changed(current: float, delta: float)

# --- Facility ---
signal power_state_changed(zone_id: StringName, powered: bool)
signal alarm_level_changed(level: int)
signal door_state_changed(door_id: StringName, is_open: bool)
signal containment_breached(scp_id: StringName)

# --- Progression ---
signal skill_xp_gained(skill_id: StringName, amount: float)
signal skill_level_up(skill_id: StringName, new_level: int)
signal document_read(document_id: StringName)
signal keycard_acquired(level: int)
```

Usage:

```gdscript
# Emitting — the emitter knows nothing about listeners
EventBus.noise_emitted.emit(global_position, 0.8, self, ["footstep", "human"])

# Listening — the listener knows nothing about emitters
func _ready() -> void:
    EventBus.noise_emitted.connect(_on_noise)
```

### 5.3 Data-driven content via Resources

Every piece of content is a typed `Resource`. Example:

```gdscript
# src/items/item_definition.gd
class_name ItemDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var world_model: PackedScene

@export_group("Physical")
@export var weight_kg: float = 0.5
@export var volume_l: float = 0.5
@export var max_stack: int = 1

@export_group("Condition")
@export var has_condition: bool = false
@export var max_condition: float = 100.0
@export var condition_loss_per_use: float = 1.0

@export_group("Behavior")
@export var categories: Array[StringName] = []   # "weapon","medical","keycard","food"
@export var use_behavior: Script                 # extends ItemBehavior
@export var behavior_params: Dictionary = {}

@export_group("Keycard")
@export var clearance_level: int = -1            # -1 = not a keycard

@export_group("Consumable")
@export var hunger_restore: float = 0.0
@export var thirst_restore: float = 0.0
@export var calories: float = 0.0
@export var protein_g: float = 0.0
@export var carbs_g: float = 0.0
@export var fat_g: float = 0.0
@export var boredom_delta: float = 0.0
@export var unhappiness_delta: float = 0.0

@export_group("SCP-914")
@export var upgrade_result: StringName = &""     # id produced on "Fine"
@export var refine_result: StringName = &""      # id produced on "Very Fine"
@export var downgrade_result: StringName = &""   # id produced on "Rough"
```

**Corollary:** adding a new item = creating one `.tres` file in `data/items/`. Zero code changes. Enforce this.

### 5.4 Component composition over inheritance

Entities are `Node3D` with child component nodes. Do **not** build a deep class hierarchy.

```
Player (CharacterBody3D)
├── Camera3D
│   └── GazeRaycaster        (player_gaze.gd)
├── NeedsComponent           (hunger, thirst, fatigue, boredom, stress)
├── HealthComponent
│   └── BodyPart × 12        (head, torso, L/R upper+lower arm, L/R hand, L/R upper+lower leg, L/R foot)
├── MoodleSystem
├── InfectionSystem
├── SanitySystem
├── TemperatureSystem
├── SkillSystem
├── Inventory
├── EquipmentSlots
├── NoiseEmitter
└── InteractionRay
```

SCPs and NPCs reuse the *same* components where applicable — an MTF operative has `HealthComponent` and `NoiseEmitter` exactly like the player. This is why 939 can hear a guard's footsteps and go kill him without any special-case code.

### 5.5 Determinism

Every run is defined by a **seed**. Given the same seed and the same player inputs, the facility layout, loot placement, and SCP spawn points must be identical. This makes bugs reproducible and enables seed sharing.

```gdscript
# src/util/rng.gd — autoload as RNG
extends Node

var _master_seed: int = 0
var _streams: Dictionary = {}   # StringName -> RandomNumberGenerator

func set_seed(s: int) -> void:
    _master_seed = s
    _streams.clear()

## Independent stream per subsystem, so adding a loot roll
## does not shift the layout generation sequence.
func stream(name: StringName) -> RandomNumberGenerator:
    if not _streams.has(name):
        var r := RandomNumberGenerator.new()
        r.seed = hash(str(_master_seed) + "::" + str(name))
        _streams[name] = r
    return _streams[name]
```

Use `RNG.stream(&"layout_floor_3")`, `RNG.stream(&"loot_floor_3")`, `RNG.stream(&"scp_patrol")` — never `randi()` directly.

---

## §6 — THE FACILITY: SITE-104

### 6.1 Floor structure

Eight floors. The player starts on Floor 1 and descends. Each floor is gated by a keycard clearance level found on the floor above (or on the floor itself, hidden behind an optional risk).

| # | Zone | Clearance to LEAVE | Size (approx) | Lighting | Primary threats |
|---|---|---|---|---|---|
| **1** | **Entrance Zone** | L1 | 120×120 m | Full, clean white | None (tutorial). Corpses, aftermath. |
| **2** | **Administration & Personnel** | L2 | 140×140 m | Full, flickering | SCP-966, hostile Class-D |
| **3** | **Light Containment** | L2 | 160×160 m | Partial outage | SCP-173, SCP-1048 |
| **4** | **Research & Testing** | L3 | 180×180 m | Emergency red | SCP-049 + 049-2, SCP-035 |
| **5** | **Heavy Containment** | L3 | 200×200 m | Mostly dark | SCP-096, SCP-939 pack |
| **6** | **Maintenance & Sublevel** | L4 | 200×200 m | Dark, sparse | SCP-106, SCP-966, flooding |
| **7** | **Deep Storage / Keter Wing** | L5 | 220×220 m | Near-total dark | SCP-106, SCP-682 (scripted), MTF |
| **8** | **The Well** | — (endgame) | Vertical, non-standard | Anomalous | Endgame sequence (§6.6) |

**Scale note:** 200×200 m of dense interior is genuinely large — roughly 60–80 rooms plus corridors. Do not build this by hand. See §6.3.

### 6.2 Per-floor character

Each floor must be **visually and mechanically distinct** so the player always knows where they are from a single screenshot.

**Floor 1 — Entrance Zone**
Clean white epoxy floors, corporate signage, reception desk, security checkpoint, decontamination showers, break room, parking sublevel entrance. Power is on. The horror is entirely environmental: overturned chairs, a half-eaten lunch, a security monitor cycling through empty corridors, blood in the decon shower drain. **No anomaly threatens the player here.** This floor teaches movement, interaction, inventory, and reading documents. It should take 10–15 minutes and end with the player *wanting* to leave.

**Floor 2 — Administration & Personnel**
Cubicle farms, Site Director's office, HR records, server room, cafeteria, dormitories, medical bay. Beige and fluorescent. First loot density spike (food, first aid, keycards on corpses). First anomaly encounter: **SCP-966** — invisible to the naked eye, and the player's first thermal-vision goggles are found here. Introduces the "you cannot see the threat" lesson.

**Floor 3 — Light Containment**
Repeating white chamber corridors, observation windows, Safe/Euclid-class cells. Introduces **SCP-173** in a scripted first encounter (a chamber with a broken observation window), then lets it roam free. Also hosts **SCP-914** (§6.5) and **SCP-1048**. Power failures begin — lights cut in sections.

**Floor 4 — Research & Testing**
Wet labs, testing chambers with one-way glass, autopsy suite, biohazard containment, cryogenic storage. Emergency lighting only — everything is red. **SCP-049** roams and converts corpses (including *your* previous deaths) into 049-2. **SCP-035** is contained here and will talk to you through the glass, offering true information mixed with lethal advice.

**Floor 5 — Heavy Containment**
Massive reinforced chambers, blast doors, catwalks over open shafts, the containment control room. Concrete, rust, and rebar. **SCP-096** is here — the most dangerous single entity in the game. **SCP-939** hunts in packs of 2–4 through the dark, and the ventilation network becomes a real navigation option.

**Floor 6 — Maintenance & Sublevel**
Pipes, generators, water treatment, flooded sections, tunnel networks, no signage. The facility's guts. **Power management becomes a mechanic** — you must restore the generator to run the elevator, and running the generator makes noise that draws everything. Partially flooded (movement penalty, hypothermia, electrocution hazard in powered water).

**Floor 7 — Deep Storage / Keter Wing**
Vault doors, containment chambers the size of aircraft hangars, no lighting whatsoever. **SCP-106** hunts freely and phases through walls. **MTF Epsilon-11 "Nine-Tailed Fox"** deploys here and will kill you on sight — they are not rescue. **SCP-682** appears as an unwinnable scripted set-piece, not a fightable enemy.

**Floor 8 — The Well**
Non-euclidean vertical shaft. Reality is degraded. This is the endgame (§6.6).

### 6.3 Level generation: hybrid prefab stitching

**Do not generate rooms procedurally from scratch** — procedural interiors look procedural, and the goal is "this feels like a real building." **Do not hand-build 600 rooms either** — that's a year of work.

**Use hybrid prefab stitching:**

1. **Hand-author a library of room prefabs** as `.tscn` scenes in `scenes/rooms/<zone>/`. Target 25–40 prefabs per zone. Each prefab has:
   - Tagged **connector nodes** (`Marker3D` named `Connector_N/S/E/W`) with a type (`door_standard`, `door_blast`, `corridor_open`, `vent`)
   - A metadata `.tres` in `data/room_prefabs/` declaring: footprint size (in 4 m grid cells), tags (`lab`, `office`, `storage`, `containment`, `utility`), spawn weight, loot table, min/max instances per floor, and whether it's `critical_path_eligible`
2. **Generate the floor graph first, geometry second.** Algorithm:

```
a) Build a floor plan as a grid of cells (e.g. 50×50 cells at 4m = 200×200 m)
b) Place MANDATORY rooms first at valid random positions:
     - stairwell_down (the exit — always placed FIRST, far from spawn)
     - elevator_shaft
     - the floor's keycard location (guaranteed reachable)
     - the floor's signature SCP chamber
c) Compute the critical path from spawn → keycard → exit using A* on the cell grid
d) Reserve the critical path cells
e) Fill remaining space with weighted-random prefabs that fit
f) Weave corridors to connect all placed rooms (corridor_weaver.gd)
     - Use a minimum spanning tree over room centers
     - Then add ~15-25% extra edges to create loops
       (loops are ESSENTIAL — a tree-shaped facility means dead ends,
        and dead ends mean unavoidable deaths, which feels unfair)
g) Place doors at every connector junction; assign clearance requirements
h) Carve the ventilation network as a SECOND, sparser graph overlaying the first
i) Distribute loot via loot_distributor.gd using per-room loot tables
j) Place SCP spawn points, patrol nodes, and 106's pocket-dimension anchors
k) Bake NavigationMesh
```

3. **Guarantee validity.** After generation, run assertions:
   - Spawn → keycard is reachable without the keycard
   - Keycard → exit is reachable with the keycard
   - Every room has ≥1 connection
   - No room overlaps
   - NavMesh is contiguous across the critical path

   If any assertion fails, **reseed and regenerate** (up to 50 attempts, then fall back to a known-good static layout). Never ship an unwinnable floor.

4. **Anti-repetition dressing.** After placement, run a `prop_scatterer` that randomizes: overturned furniture, blood decals, debris, papers, flickering-light assignments, and corpse placement. Two instances of the same office prefab must never look identical.

### 6.4 Doors, keycards, and clearance

| Clearance | Color | Grants access to |
|---|---|---|
| **L0** | Grey | Nothing. Class-D default. Public corridors only. |
| **L1** | White | Utility closets, break rooms, Floor 1→2 stairwell |
| **L2** | Blue | Offices, Safe-class chambers, Floor 2→3 and 3→4 |
| **L3** | Green | Research labs, Euclid chambers, Heavy Containment, Floor 4→5 and 5→6 |
| **L4** | Orange | Site Director's office, Keter wing, armory, Floor 6→7 |
| **L5** | Red | Everything. Thaumiel storage. Floor 7→8. |

Design rules:
- **Never gate the critical path behind exactly one keycard.** Every floor has ≥2 valid ways to obtain the required clearance (e.g. find the card, OR upgrade a lower card in SCP-914, OR cut power to the reader and force the door with a crowbar at a stamina/noise cost).
- **Keycards have condition.** They degrade with swipes and can be destroyed by SCP-106's corrosion or SCP-914 mishaps.
- Doors have states: `LOCKED`, `UNLOCKED`, `OPEN`, `JAMMED`, `POWERED_DOWN`, `WELDED`. A powered-down door can be pried open (Strength check + crowbar, high noise). A welded door cannot.
- **Blast doors** seal automatically during a facility lockdown and require the control room to reopen.

### 6.5 SCP-914 — the upgrade system

Located on Floor 3. This is the game's crafting-adjacent gambling system and it's a major reason to backtrack.

Five settings. Input an item, get a transformed output:

| Setting | Effect | Example |
|---|---|---|
| **Rough** | Violently destroys/degrades | Keycard L3 → shredded plastic |
| **Coarse** | Crude downgrade or breakdown into parts | Radio → wires + battery + casing |
| **1:1** | Repairs/cleans/duplicates in kind | Damaged keycard → pristine keycard of same level |
| **Fine** | Meaningful upgrade | Keycard L2 → Keycard L3; bandage → sterile dressing |
| **Very Fine** | Dramatic, often unpredictable upgrade | Keycard L4 → Keycard L5; 9V battery → anomalous power cell |

Implementation: `upgrade_result` / `refine_result` / `downgrade_result` fields already exist on `ItemDefinition` (§5.3). Unmapped items fall back to a category-based table, then to "destroyed." **Include a small chance of anomalous outcomes** on Very Fine (5%): the machine produces something unrelated and unsettling. Log every 914 use to a facility incident report the player can later find.

### 6.6 The endgame — Floor 8 "The Well"

The bottom of the site is not a room. It is a vertical shaft that should not be as deep as it is. Design goals: reality degradation, no combat, three possible endings.

**Endings:**

| Ending | Requirement | Outcome |
|---|---|---|
| **Containment** | Reach the bottom, activate the site's nuclear warhead, do not escape | Site-104 is scrammed. You die. The Foundation's cover story holds. Best "canonical" ending. |
| **Escape** | Reach the surface elevator with an L5 card and survive MTF | You get out into a world that has no idea. Amnestics ending — you are found and dosed. |
| **Breach** | Release SCP-682 or fully enable SCP-079 | The site falls. Cascade failure. Worst outcome, most interesting to reach. |

Show a Foundation-style incident report over the credits summarizing the player's run: deaths caused, anomalies breached, documents recovered, days survived. Generate it from run telemetry — this is cheap to build and enormously satisfying.

---

## §7 — SCP ROSTER

All entries below are lore-accurate to the SCP Wiki. **Every one requires attribution in `docs/ATTRIBUTION.md` (§2.2), and none may use the wiki's images (§2.3).**

### 7.1 The `SCPDefinition` resource

```gdscript
# src/scps/scp_definition.gd
class_name SCPDefinition
extends Resource

@export var designation: StringName          # "SCP-173"
@export var nickname: String                 # "The Sculpture"
@export var object_class: StringName         # Safe/Euclid/Keter/Thaumiel/Apollyon
@export_multiline var containment_procedures: String
@export_multiline var description: String
@export var article_url: String              # for attribution
@export var article_authors: Array[String]

@export_group("Gameplay")
@export var scene: PackedScene
@export var floors: Array[int]               # which floors it may appear on
@export var is_mobile: bool = true
@export var can_open_doors: bool = false
@export var can_phase_walls: bool = false
@export var required_clearance_to_view: int = 0

@export_group("Perception")
@export var detects_by_sight: bool = false
@export var detects_by_sound: bool = false
@export var detects_by_gaze: bool = false     # 173/096 mechanics
@export var hearing_radius_m: float = 20.0
@export var sight_range_m: float = 25.0

@export_group("Threat")
@export var move_speed_walk: float = 2.0
@export var move_speed_chase: float = 6.0
@export var sanity_drain_per_sec_visible: float = 0.0
@export var is_killable: bool = false
@export var health: float = -1.0              # -1 = invulnerable
```

### 7.2 Object classes (canon reference)

Implement these as the displayed classification on documents and terminals. Accuracy matters to the audience.

**Primary:**
- **Safe** — Easily and reliably contained. Does not mean harmless; means containment is cheap.
- **Euclid** — Requires more resources; containment isn't always reliable, usually because it's insufficiently understood or unpredictable. Most sapient/autonomous anomalies land here. The broadest class.
- **Keter** — Extremely difficult and costly to contain; frequent breaches; lengthy procedures. **Keter does not mean "most dangerous" — it means "hardest to keep in the box."**
- **Thaumiel** — Anomalies the Foundation uses to contain *other* anomalies. Existence classified at the highest levels; known to few outside the O5 Council.

**Secondary/esoteric (use sparingly, on documents only):**
- **Apollyon** — Cannot be contained; breach is imminent or inevitable; usually tied to K-Class scenarios.
- **Archon** — Could theoretically be contained, but the Foundation *chooses* not to.
- **Neutralized** — No longer anomalous.
- **Explained** — Now fully understood by mainstream science, or debunked.
- **Pending** — Classification not yet assigned.

The informal guideline is the **Locked Box Test**: lock it in a box and leave it. Nothing happens → Safe. Not sure what happens → Euclid. It gets out → Keter. It *is* the box → Thaumiel.

### 7.3 Primary roster — full implementation

#### SCP-173 — "The Sculpture" · Euclid · Floor 3
**Canon:** Animate sculpture of concrete and rebar, with traces of Krylon brand spray paint. It cannot move while within direct line of sight of a living being. Blinking counts as breaking line of sight. It kills by snapping the neck at the base of the skull, or by strangulation.

**Implementation:**
- Movement is gated entirely by the gaze system (§9.1). `_physics_process` checks `GazeSystem.is_observed(self)`. If observed → velocity zero, absolutely frozen, no animation whatsoever (not even idle — it must be uncannily still).
- If unobserved → teleport-step toward the nearest unobserved-adjacent navmesh point at high speed. **Do not lerp.** The horror is the discontinuity: you blink and it has moved 4 meters.
- Kill is instant on contact. No health bar, no fight.
- Leaves a trail of dry, flaked spray paint and a specific ochre residue the player can find and learn to read as a warning.
- **Multiple observers stack.** An NPC guard looking at 173 freezes it for you too — creating an emergent mechanic where you keep a corpse-less guard alive as a mobile "lock."
- **⚠️ LICENSING: original model design only. See §2.3.**

#### SCP-096 — "The Shy Guy" · Euclid · Floor 5
**Canon:** Humanoid, ~2.38 m tall, emaciated, pallid, extremely long arms, almost no muscle mass. Docile — paces its cell and sits. If any human views its face — **in person, in a photograph, in a video recording, in any medium** — 096 covers its face, screams, cries, and babbles for 1–2 minutes ("the trigger phase"), then pursues the viewer at extreme speed regardless of distance or obstacles, kills them, and returns to docility. Highly resistant to small-arms fire.

**Implementation — this is the game's set-piece system:**
- **Face-view detection** is the strictest use of the gaze system. Requires: (a) 096's head within the camera frustum, (b) unobstructed raycast to the head bone, (c) the head's forward vector within ~120° of the camera, (d) NOT obscured by 096's own hands.
- **Trigger phase:** 90 seconds. 096 collapses, covers its face, and screams. The scream is audible facility-wide with distance-based filtering. The player has 90 seconds to run, hide, and pray. **Do not shorten this.** The dread of the timer is the entire mechanic.
- **Pursuit:** 096 runs at ~11 m/s (unoutrunnable), pathfinds directly, and **breaks through standard doors and drywall**. It ignores all other entities. Only a sealed blast door stops it — and only temporarily.
- **Photographs count.** Place documents and monitors in the world showing 096's face. A player who reads the wrong file in a safe office triggers it from three floors away. This is the single best "the Foundation's own paperwork kills you" moment in the game.
- **SCP-1499 (gas mask) is the counter** — while in the alternate dimension you are not "viewing." Also: closing your eyes (hold a key) prevents the trigger but blinds you.
- After a kill, 096 returns to docility wherever it stands. It does not go home.

#### SCP-106 — "The Old Man" · Keter · Floors 6–7
**Canon:** Elderly humanoid with a severely decayed, rotting appearance. Produces a corrosive black mucus that causes solid matter to soften and rot. Can pass through solid matter, leaving a corrosion mark. Prefers to incapacitate prey (typically by breaking bones in the legs) and drag it into its "pocket dimension." Not fast, but relentless.

**Implementation:**
- **Phasing:** 106 ignores navmesh and walls. It emerges from surfaces. Implement as: pick a target point near the player, play a "corrosion pool" emergence VFX on the nearest wall/floor, then materialize. Terrifying and cheap to build.
- **Corrosion trail:** leaves permanent black decals and *actually damages the level* — corroded floor sections can collapse, creating new holes between floors. Persist these in `FacilityState`.
- **Capture, not kill:** on contact, the player is dragged into the **pocket dimension** — a separate small scene, dark, distorted, with a hunting 106. The player must find the exit within a time limit. Escaping returns you to a random location on the current floor with a broken leg and heavy sanity loss. **Failing means death.** This is far better than an instant kill.
- **Recall protocol:** the femur breaker in Heavy Containment recalls 106 to its containment cell. Using it requires a sacrifice (an NPC, or severe self-injury). Deeply grim, canon-accurate, and a genuine moral choice.
- 106 cannot be killed. Ever.

#### SCP-049 — "The Plague Doctor" · Euclid · Floor 4
**Canon:** Humanoid, ~1.9 m, appearing to wear the garb of a medieval plague doctor — but the "mask" is part of its body. Sapient, articulate, polite, and cooperative when not agitated. Believes it is curing "the Pestilence." Physical contact causes near-instant death in humans. It then performs crude surgery on the corpse, reanimating it as an **SCP-049-2** instance. Vulnerable to conventional firearms.

**Implementation:**
- **049 talks.** Full dialogue system. It addresses the player politely, discusses its work, and can even *help* — it will unlock doors for you if it believes you're assisting its research. It becomes hostile only when it decides you are infected.
- **Touch = death.** Not a damage number. Contact triggers a death sequence.
- **049-2 instances** are the game's only conventional enemies: slow, groaning, reanimated staff in torn lab coats and security uniforms. They swarm. They're individually weak (killable with melee) but attritional — they cost you stamina, health, and noise.
- **⚠️ Critical mechanic: 049 converts YOUR previous corpses.** If you died on Floor 4 in a prior run/life (§18.3), that body becomes an 049-2 wearing your gear. Your own loot is now trying to kill you. This is the single best idea in this document — implement it.
- 049 is killable with sustained firearm fire, but ammunition is extremely scarce and gunfire is the loudest thing in the game.

#### SCP-939 — "With Many Voices" · Keter · Floors 5–7
**Canon:** Pack-hunting, obligate carnivorous, ~2.2 m, red-skinned, with multiple eyes that are non-functional — **939 is effectively blind**. It hunts by sound. It produces speech in the voices of people who have died near it, using these to lure prey. It exhales a corrosive vapor.

**Implementation — this is the game's audio showpiece:**
- **Zero sight.** 939 has no vision cone at all. It navigates entirely by the noise propagation system (§9.2). This makes it the perfect teacher for sound mechanics.
- **Voice mimicry:** 939 records lines from NPCs who die near it and replays them. If a researcher screams "Help me, please, is someone there?" and dies, 939 will use that exact line, in that exact voice, for the rest of the run. Implement as a runtime voice-clip registry per 939 instance.
- **Advanced:** if the player uses proximity voice chat in multiplayer (§21.6), 939 mimics *the player's own teammates*.
- **Packs of 2–4.** They coordinate: one calls, others flank toward whoever responds.
- **Counterplay:** move slowly (crouch-walk emits ~0.1 loudness vs. 0.9 for sprinting), throw objects to create decoy noises, and use the ventilation system where sound propagates differently.
- Killable with sustained fire, but killing one alerts the whole pack.

#### SCP-079 — "Old AI" · Euclid · Facility-wide (Floor 2 server room)
**Canon:** A sapient AI running on a modified Exidy Sorcerer microcomputer from 1978. Its memory is severely limited — it can only retain roughly 24 hours of new information before overwriting. It is hostile, arrogant, and constantly attempts to escape onto any connected network.

**Implementation:**
- 079 is the **facility's antagonistic dungeon master.** If the player restores the site network, 079 gains control of doors, lights, elevators, and the PA system.
- It **negotiates.** It will open your path in exchange for you extending its reach. Every deal you make gives it more control — and it lies, badly, because its memory is failing.
- Its 24-hour memory limit is a *mechanic*: it forgets your betrayals. It also forgets its promises.
- It speaks in flat synthesized text-to-speech over the PA. Its dialogue is displayed as green monospace CRT text on terminals.
- **Choice:** the player can permanently sever 079 (destroying the remote door system, meaning every door must be opened manually forever) or leave it active (fast travel via elevators, at the cost of an intelligent enemy controlling the building).

#### SCP-966 — "Sleeper" · Euclid · Floors 2, 6
**Canon:** Predatory, emaciated, sinewy humanoid entities that are **invisible in the visible spectrum** but plainly visible in infrared. They cause severe insomnia in nearby humans and feed on sleeping prey.

**Implementation:**
- Rendered only on the thermal-vision layer. **Completely invisible otherwise** — not translucent, not shimmering. Nothing.
- Presence causes escalating **insomnia**: within ~30 m the player's fatigue recovery drops to zero and sanity drains. Sleeping anywhere near one is fatal.
- The **thermal goggles** (found Floor 2) are the counter — but they have limited battery and severely restrict peripheral vision.
- **Best moment in the game:** the player puts on thermal goggles in a corridor they've walked through six times and finds four of them standing perfectly still, watching.

#### SCP-035 — "Possessive Mask" · Keter · Floor 4
**Canon:** A white porcelain comedy/tragedy mask that constantly secretes a highly corrosive viscous fluid. Anyone who sees it feels a compulsion to wear it; on contact it attaches to the face permanently, and the host body decays while 035 takes control. Extremely intelligent and persuasive.

**Implementation:**
- 035 is contained behind glass and **talks to the player**. It is charming, funny, and helpful. It offers genuinely correct information about the facility — keycard locations, safe routes, what's coming — mixed with advice designed to kill you.
- It is the game's unreliable narrator. Track a hidden `trust_035` value; the more the player follows its advice, the more it escalates.
- Wearing the mask is possible and is an instant, irreversible bad ending.
- Sanity drain while looking at it. Compulsion effect: the interact prompt for its case appears even when the player isn't aiming at it.

#### SCP-1048 — "Builder Bear" · Euclid · Floor 3
**Canon:** A small teddy bear capable of independent movement, apparently friendly, which draws pictures and communicates non-verbally. It constructs copies of itself from materials including human ears, cartilage, and other body parts.

**Implementation:** Comic relief that curdles. 1048 follows the player, waves, draws pictures. Its constructs (**1048-A/B/C**) appear later — made of ears, made of screaming faces. Harmless directly; enormous sanity drain. It is the game's best tonal whiplash.

### 7.4 Object roster (non-hostile anomalies as items)

| SCP | Class | Effect | Location |
|---|---|---|---|
| **SCP-500** | Safe | "Panacea" — red pill, cures any disease/infection/injury instantly. **Extremely rare, 1–2 per run.** | Floor 4 medical |
| **SCP-268** | Safe | Tweed cap. While worn, others' attention slides off you. Reduces detection radius by 70%. Effect degrades if you draw attention. | Floor 2 |
| **SCP-1499** | Safe | Gas mask. Wearing it transports you to a dark alternate dimension with hostile entities. Removing it returns you — **to wherever you walked while there.** Ultimate escape tool and ultimate risk. | Floor 5 |
| **SCP-427** | Safe | Lovecraftian locket. Rapid healing while worn. Prolonged use transforms the wearer into a mass of muscle tissue. Track cumulative wear time. | Floor 4 |
| **SCP-999** | Safe | Orange gelatinous mass, euphoric to the touch. Fully restores sanity, removes stress/unhappiness/panic. Follows the player briefly. **The one kind thing in the entire game.** | Floor 3, hidden |
| **SCP-294** | Safe | Coffee machine. Type any liquid; it dispenses it. Implement as a text input with a lookup table + jokes + a few genuinely useful outputs (water, painkillers dissolved, "blood of my enemies"). | Floor 2 cafeteria |
| **SCP-513** | Euclid | Rusty cowbell. Ringing it summons **SCP-513-1**, an entity visible only in peripheral vision that causes escalating terror. Permanent for the run. | Floor 6 |
| **SCP-914** | Safe | The Clockworks (§6.5) | Floor 3 |
| **SCP-682** | Keter | Scripted set-piece only. Never fightable. | Floor 7 |

### 7.5 Human factions

**Class-D personnel** — Orange jumpsuits. Death-row inmates. Some are allies (trade, information), some are hostile (they want your keycard). Terrified, unarmed, and useful as unwitting 173 observers or 939 bait. Killing them has a sanity cost.

**Site security / guards** — Grey uniforms, Level 2–3 clearance, armed with sidearms. Hostile to Class-D on sight during a breach (standing orders). Their corpses carry keycards and ammunition.

**Researchers** — Lab coats. Non-combatant, panicking. Will trade information and keycards for escort to a stairwell. **Escort missions where the escortee is genuinely useful** (they know door codes) rather than a burden.

**MTF Epsilon-11 "Nine-Tailed Fox"** — Deploys on a timer after the alarm reaches maximum, or on Floor 7. Full tactical gear, night vision, coordinated squad AI, automatic weapons. Their mandate is recontainment and **termination of all Class-D**. They are not a rescue. Encountering them should feel like the world's most competent people arriving to clean up, and you are part of the mess.

*(Reference for flavor/documents: MTF Nu-7 "Hammer Down" heavy assault, Alpha-1 "Red Right Hand" O5 direct, Eta-10 "See No Evil" visual cognitohazards, Beta-7 "Maz Hatters" hazmat.)*

---

## §8 — CLEARANCE, DOCUMENTS & THE REDACTION SYSTEM

This is the primary lore-delivery mechanism and one of the game's best original systems.

### 8.1 Progressive declassification

Every document in `data/documents/*.json` is authored **at full Level-5 detail**, with spans tagged by the clearance required to read them:

```json
{
  "id": "doc_incident_104_11",
  "title": "Incident Report 104-11",
  "doc_type": "incident_report",
  "found_on_floor": 4,
  "body": [
    {"clearance": 0, "text": "At 03:47 on ██/██/████, containment of "},
    {"clearance": 3, "text": "SCP-049", "redacted_as": "[REDACTED]"},
    {"clearance": 0, "text": " failed following "},
    {"clearance": 2, "text": "a power interruption in Sector 4",
     "redacted_as": "[DATA EXPUNGED]"},
    {"clearance": 0, "text": ". Casualties: "},
    {"clearance": 1, "text": "17 personnel", "redacted_as": "██"},
    {"clearance": 4, "text": " The interruption was not accidental. Refer to O5-█ standing order.",
     "redacted_as": ""}
  ]
}
```

The document viewer renders spans the player has clearance for, and renders `redacted_as` (black bars, `[REDACTED]`, `[DATA EXPUNGED]`) otherwise. **A player who finds an L4 card can and should go back and re-read every document they've already collected.** Mark re-readable documents in the journal with a "new information available" indicator.

This means: **the story is gated behind the same keycards as the level progression**, and reading is a genuine reward.

### 8.2 Document types

Author 60–120 documents across the site. Types:
- **SCP articles** — the real containment procedures, rendered in authentic wiki format
- **Incident reports** — what went wrong, in dry bureaucratic language
- **Interview logs** — Dr. ██████ interviewing an anomaly, in transcript format
- **Personnel files** — including one for **you**, D-9341, listing your crime and your assigned test schedule
- **Test logs** — 914 experiments, 049 procedures, D-Class expenditure
- **Email chains** — the site director arguing with Site Command about budget while people die
- **Handwritten notes** — the only non-bureaucratic voice in the game
- **Memoranda** — including the one authorizing your termination

### 8.3 Amnestics

Class A through E amnestics exist as items. Mechanically:
- **Class-A** — removes recent memory: clears the player's map data for the current floor, but also removes cognitohazard sanity debuffs and 513-1
- **Class-B/C** — stronger; removes more map data, cures more severe mental effects
- **Class-E** — restores memory (counteragent)

This turns amnestics into a genuine tradeoff rather than a lore prop, and it's mechanically unique.

---

## §9 — PERCEPTION SYSTEMS (THE HARD PART)

**Most SCP games fail here.** They implement "is 173 observed?" as a distance check and a dot product, and it feels wrong immediately. Do this properly — it is the technical core of the game.

### 9.1 The gaze system

An entity is **observed** if and only if all of the following are true:

1. Its designated `observation_point` (a `Marker3D` on the model, usually the head/center of mass) is inside the observer's camera frustum
2. A raycast from the camera to that point is **unobstructed** by world geometry
3. The angle from camera-forward to the point is within the observer's `attention_cone` (narrower than the render frustum — see below)
4. The observer's eyes are open (player not blinking, NPC not dead/unconscious)
5. The observer is a living, conscious entity with functioning vision

```gdscript
# src/player/player_gaze.gd
class_name PlayerGaze
extends Node3D

@export var camera: Camera3D
## Full render FOV is ~75°, but human ATTENTION is narrower.
## Beyond this, you technically "see" but do not "observe".
@export var attention_cone_deg: float = 55.0
@export var peripheral_cone_deg: float = 75.0
## Peripheral observation is partial — enough to slow 173, not stop it.
@export var peripheral_effectiveness: float = 0.35

var _observed_now: Dictionary = {}   # Node3D -> float (observation strength 0..1)
var _observed_last: Dictionary = {}
var is_blinking: bool = false

func _physics_process(_d: float) -> void:
    _observed_last = _observed_now.duplicate()
    _observed_now.clear()
    if is_blinking:
        _emit_transitions()
        return

    for target in get_tree().get_nodes_in_group(&"observable"):
        var strength := _evaluate(target)
        if strength > 0.0:
            _observed_now[target] = strength
    _emit_transitions()

func _evaluate(target: Node3D) -> float:
    var point: Node3D = target.get_node_or_null(^"ObservationPoint")
    var world_pos: Vector3 = point.global_position if point else target.global_position

    # 1. Frustum test (cheap, do first)
    if not camera.is_position_in_frustum(world_pos):
        return 0.0

    # 2. Attention cone
    var to_target := (world_pos - camera.global_position)
    var dist := to_target.length()
    var angle := rad_to_deg(camera.global_basis.z.normalized().angle_to(-to_target.normalized()))
    var cone_factor := 0.0
    if angle <= attention_cone_deg * 0.5:
        cone_factor = 1.0
    elif angle <= peripheral_cone_deg * 0.5:
        cone_factor = peripheral_effectiveness
    else:
        return 0.0

    # 3. Occlusion raycast
    var space := get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.create(
        camera.global_position, world_pos,
        1 << 0,                      # world geometry layer only
        [self, get_parent()]
    )
    var hit := space.intersect_ray(q)
    if not hit.is_empty():
        return 0.0

    # 4. Light level — you cannot observe what you cannot see
    var light := LightProbe.sample_at(world_pos)   # see §9.4
    if light < 0.02:
        return 0.0
    var light_factor: float = clampf(remap(light, 0.02, 0.35, 0.0, 1.0), 0.0, 1.0)

    # 5. Distance falloff
    var dist_factor: float = clampf(remap(dist, 40.0, 8.0, 0.0, 1.0), 0.0, 1.0)

    return cone_factor * light_factor * dist_factor

func _emit_transitions() -> void:
    for t in _observed_now:
        if not _observed_last.has(t):
            EventBus.player_gaze_entered.emit(t)
    for t in _observed_last:
        if not _observed_now.has(t):
            EventBus.player_gaze_exited.emit(t)
```

**Critical detail — observation is not binary.** Returning a *strength* rather than a bool is what makes 173 feel right: at the edge of your vision, in a dark room, at 30 m, you only partially hold it. It creeps. That creeping is the entire scare.

### 9.2 Blinking

Blinking must be a real, uncomfortable mechanic:
- Involuntary blink every 4–8 seconds (randomized via `RNG.stream(&"blink")`), lasting 0.15 s, with a **full screen-black** (not a fade — an actual eyelid animation)
- **Blink pressure** builds when the player holds their eyes open (hold a key to suppress). At high pressure, vision blurs, sanity drains, and the eventual forced blink lasts 0.4 s
- Dry air (Floor 6 vents), smoke, and 106's corrosion vapor all accelerate blink pressure
- The HUD shows nothing about this. The player learns it by dying.

### 9.3 Noise propagation

Sound is a first-class simulation, not a sphere check. Every noise event:

```gdscript
EventBus.noise_emitted.emit(position, loudness, source, tags)
```

**Loudness reference table** (0.0–1.0):

| Action | Loudness |
|---|---|
| Crouch-walking | 0.08 |
| Walking | 0.25 |
| Running | 0.55 |
| Sprinting | 0.85 |
| Opening a standard door | 0.30 |
| Opening a blast door | 0.90 |
| Melee swing (hit) | 0.45 |
| Melee swing (miss, hits wall) | 0.60 |
| Firing a pistol | **1.00** |
| Firing a rifle | **1.00** |
| Breaking a window | 0.80 |
| Throwing an object (impact) | 0.50 |
| Generator running | 0.70 (continuous) |
| Coughing / vomiting (sickness) | 0.35 |
| Screaming (panic) | 0.95 |

**Propagation:** do not use raw distance. Use **navmesh path distance** with per-obstacle attenuation:

```
effective_loudness = loudness
                   * exp(-path_distance / falloff_constant)
                   * product(attenuation of each door/wall crossed)
```

Attenuation values: open doorway ×1.0, closed standard door ×0.4, closed blast door ×0.05, ventilation duct ×0.85 (**ducts carry sound further than corridors — this is why the vents are dangerous**), water ×0.6.

This means a gunshot two rooms away through a closed door is quieter than a footstep in the same room, which is correct and which players intuitively understand.

**Ambient noise floor** masks quiet sounds: running generators, HVAC, and alarms all raise the floor. Sneaking past 939 during an alarm is *easier* — a genuinely interesting tactical inversion.

### 9.4 Light sampling

Both the gaze system and enemy sight need to know "how lit is this point?" Godot doesn't expose this cheaply. Implement a `LightProbe` helper:

- Maintain a registry of all active `Light3D` nodes
- For a query point: sum contributions from lights within range, each attenuated by distance, cone angle (for spots), and an occlusion raycast
- Cache per-point results for 0.2 s (this is called every frame by multiple systems — caching is not optional)
- Add a small ambient floor per floor (Floor 1 = 0.4, Floor 7 = 0.0)

This single system drives: 173's observation checks, enemy sight ranges, the player's own visibility to guards, sanity drain in darkness, and whether the flashlight is worth the noise/battery/visibility tradeoff.

---

## §10 — THE PROJECT ZOMBOID LAYER: SURVIVAL SIMULATION

This section ports Project Zomboid's systemic depth into the SCP setting. Every PZ system below is included; each is reframed so it makes sense for a prisoner trapped in a research facility rather than a survivor in rural Kentucky.

### 10.1 Moodles → "Biometric Status"

PZ's moodles become the Foundation's **biomonitor readout** — Class-D personnel are implanted with monitoring devices, which is both canon-plausible and a great diegetic HUD justification. Icons appear in the top-right, stacked, each with 1–4 severity levels.

Implement all of these as `.tres` files in `data/moodles/`:

| Moodle | Driver | Effect at high severity |
|---|---|---|
| **Hungry** | Calorie deficit | Strength/endurance loss, then health drain |
| **Thirsty** | Water level | Endurance collapse, then health drain |
| **Tired** | Fatigue | Slowed actions, blurred vision, forced micro-sleeps |
| **Endurance** | Stamina depletion | Cannot run; melee damage down |
| **Pain** | Injury total | Blocks sleep, blocks exercise, screen distortion |
| **Injured** | Body part damage | Reduced limb function |
| **Bleeding** | Open wounds | Continuous health loss; blood pool trail (**939 and 049 track blood**) |
| **Sick** | Illness / poison | Vomiting (loud), stat penalties |
| **Panic** | Anomaly proximity | Aim sway, cannot perform fine tasks (lockpicking, suturing), heavy breathing (**loud**) |
| **Stress** | Sustained threat, darkness | Slower skill XP, panic threshold lowered |
| **Unhappy** | Injury, dark, bad food, corpses | Slower actions, reduced XP gain |
| **Bored** | Idle, no stimulus | Feeds Unhappy; countered by reading documents |
| **Heavy Load** | Carry weight ratio | Slower, cannot sprint, louder footsteps |
| **Wet** | Water, sprinklers, Floor 6 flooding | Accelerates Hypothermia |
| **Hypothermia** | Cold + wet | Shivering (**loud**), motor control loss, unconsciousness |
| **Hyperthermia** | Heat (Floor 6 boiler rooms, fires) | Dehydration acceleration, blackouts |
| **Has a Cold** | Prolonged wet/cold | Sneezing/coughing (**loud, uncontrollable**) — potentially lethal near 939 |
| **Restricted Movement** | Bulky clothing/gear | Slower, less nimble |
| **Uncomfortable** | Poor clothing fit, wet clothes | Feeds Stress and Unhappy |
| **Noxious Smell** | Blood, 106 corrosion, decay on you | **Increases detection radius for all scent-capable entities** |
| **Drunk** | Alcohol (medical stores) | Reduces Panic and Pain, wrecks accuracy and balance |
| **Angry** | *(reframed)* Cognitohazard exposure | Erratic, forced actions |
| **Food Eaten** | Recent meal | Positive: temporary morale and stamina bonus |
| **Infected** | *(SCP-specific)* Pestilence/prion exposure | See §10.5 |
| **Cognitohazard** | *(SCP-specific)* Memetic exposure | Visual/audio hallucinations, unreliable HUD |
| **Dead** | Terminal | Run over |

**Design rule:** several moodles increase noise output. This is the through-line that ties PZ's survival sim to SCP horror — *being unwell makes you audible, and being audible kills you.* A player with a cold, hypothermia, and panic is broadcasting their position continuously.

### 10.2 Health model — body parts and injuries

**Twelve tracked body parts:** Head, Neck, Torso (upper/lower), Left/Right Upper Arm, Left/Right Forearm, Left/Right Hand, Left/Right Upper Leg, Left/Right Lower Leg, Left/Right Foot.

Each `BodyPart` tracks:

```gdscript
class_name BodyPart
extends Resource

@export var part_id: StringName
@export var health: float = 100.0
@export var bleeding_rate: float = 0.0      # HP/sec
@export var pain: float = 0.0
@export var is_fractured: bool = false
@export var is_bandaged: bool = false
@export var bandage_dirty: bool = false
@export var is_sutured: bool = false
@export var is_splinted: bool = false
@export var infection_level: float = 0.0    # local wound infection
@export var has_deep_wound: bool = false
@export var has_glass_shard: bool = false
@export var burn_severity: float = 0.0
```

**Injury types and treatments:**

| Injury | Cause | Treatment | If untreated |
|---|---|---|---|
| Scratch | Debris, 049-2 | Disinfect + bandage | Minor infection risk |
| Laceration | Glass, blades, 939 claws | Disinfect + bandage; suture for faster heal | Heavy bleeding |
| Deep wound | Impalement, severe trauma | **Suture required** (needle + thread; First Aid skill check) | Will not stop bleeding |
| Bite | 049-2, 939 | Disinfect + bandage | **Pestilence infection (§10.5)** |
| Fracture | Falls, 106's leg-break, blunt trauma | **Splint required** (wood/metal + rag) | Limb unusable; movement halved |
| Burn | Fire, electrical, chemical | Cool + sterile dressing | Severe pain, high infection |
| Glass shard | Broken windows | **Tweezers** to remove before bandaging | Bandaging over glass makes it worse |
| Corrosion | SCP-106 mucus | Water flush immediately, then dressing | Spreading, untreatable after 60 s |

**Medical items:** ripped sheets (dirty bandage), sterile dressing, bandage, alcohol wipes, disinfectant, needle + suture thread, splint, tweezers, painkillers, antibiotics, adrenaline shot, Class A–E amnestics, SCP-500 (universal cure), SCP-427 (regeneration with a body-horror cost).

**Bandage hygiene:** bandages get dirty over time and must be changed. Dirty bandages *increase* infection rate. This is a small detail that makes the medical system feel real.

### 10.3 Needs

| Need | Range | Depletion | Notes |
|---|---|---|---|
| Hunger | 0–100 | ~1.4/hr baseline, scaled by exertion | Feeds calorie/weight system |
| Thirst | 0–100 | ~2.1/hr, doubled when panicking or hyperthermic | Water fountains, taps (**taps fail when power/water is cut**), bottled water |
| Fatigue | 0–100 | ~4.2/hr awake | Requires actual sleep in a safe location |
| Boredom | 0–100 | Rises when idle/repetitive | **Reading documents is the primary cure** — elegantly ties lore to a mechanic |
| Unhappiness | 0–100 | Rises from injury, darkness, corpses, bad food | Slows XP, slows actions |
| Stress | 0–100 | Rises from threat proximity, darkness, low health | Lowers panic threshold |
| Panic | 0–100 | Spikes on anomaly sighting | Decays over time; beta-blockers reduce |

### 10.4 Nutrition & body composition

Full PZ nutrition port. Food carries **calories, protein, carbohydrates, fat** in addition to hunger restoration.

- Track `body_weight_kg` and `fitness`. Sustained calorie deficit → weight loss → **Underweight** trait effects (reduced strength, reduced health pool). Sustained surplus → weight gain → reduced endurance.
- **Class-D start underweight and malnourished.** This is canon-flavored and immediately establishes fragility.
- Foods spoil. The facility has been in breach for an unknown period; cafeteria food is a gamble. **Rotten food causes Sick.**
- Cooking is possible in the cafeteria (Floor 2) — if the power is on.
- **Setpiece:** Floor 4 has a functional vending machine behind an L3 door. Players will remember it.

### 10.5 Infection — replacing the Knox Infection

PZ's signature "you got bitten, you're dead in 3 days, keep playing" mechanic maps perfectly. Implement **three distinct infection tracks**:

**1. Wound Infection (mundane, curable)**
Local, per-body-part. Caused by untreated wounds. Cured by disinfectant + antibiotics. Escalates to fever, then sepsis, then death over ~2 in-game days. This is the common one and the one the medical skill system revolves around.

**2. The Pestilence (SCP-049, terminal)**
Contracted from 049's touch (instant) or 049-2 bites (chance-based). **There is no cure except SCP-500.** Progression over ~6 in-game hours:
- *Stage 1 (0–2 hr)* — Slight fever. Barely noticeable. **The player may not realize.**
- *Stage 2 (2–4 hr)* — Nausea, weakness, `Sick` moodle. Strength penalty.
- *Stage 3 (4–5.5 hr)* — Severe. Vision desaturates. Constant coughing (**loud**).
- *Stage 4 (5.5–6 hr)* — Collapse.
- *Death* — The player becomes an **SCP-049-2 instance** in the world. Their next character will encounter their own reanimated corpse wearing their gear.

Do not tell the player they are infected. Show symptoms. Let them diagnose themselves.

**3. Memetic/Cognitohazard Contamination**
From viewing cognitohazardous material (SCP-035, certain documents, SCP-895 feeds). Effects: hallucinated entities that aren't there, false HUD readouts, phantom sounds, doors that appear where none are. **Curable with amnestics.** This is the system that lets the game lie to the player fairly — because the player has a cure and chose not to take it.

### 10.6 Temperature

Body temperature simulated from: ambient zone temperature, clothing insulation (per body part), wetness, wind (Floor 6 ventilation shafts), and exertion.

- Floor 1–4: climate controlled, ~21°C. Non-issue while power holds.
- **Floor 4 cryogenic storage: −18°C.** Requires cold-weather gear or extremely fast movement.
- **Floor 6: flooded, ~8°C water.** Wading causes rapid hypothermia. Also: if the power is on and you enter the water, you die.
- **Floor 6 boiler room: 48°C.** Hyperthermia, rapid dehydration.
- Clothing has `insulation`, `wind_resistance`, and `water_resistance` per slot, and can be layered.

### 10.7 Skills

Full PZ-style skill tree. Each skill: level 0–10, XP-gated with escalating requirements, boosted by **skill books** (a per-level-band XP multiplier) and **training VHS tapes** (direct XP). Reframed for the facility.

**Passive**
- **Fitness** — stamina pool, recovery rate. Trained by sustained exertion.
- **Strength** — carry capacity, melee damage, ability to force doors.

**Agility**
- **Sprinting** — top speed, acceleration
- **Lightfooted** — reduces footstep loudness (**the single most valuable skill in this game**)
- **Nimble** — movement speed while aiming/crouched
- **Sneaking** — reduces visual detection radius

**Combat**
- **Blunt** (pipes, wrenches, fire extinguishers), **Blade** (scalpels, knives, machetes), **Axe** (fire axes), **Spear** (improvised, rebar), **Aiming**, **Reloading**

**Medical & Science** *(reframed from PZ's Survivalist tree)*
- **First Aid** — bandaging speed/effectiveness, suturing success, splinting, diagnosis accuracy
- **Chemistry** — synthesizing disinfectant, sedatives, explosives from lab supplies
- **Biology** — identifying infection stage, understanding anomalous biology, safer 049-2 handling
- **Foraging** *(reframed as* **Scavenging***)* — reveals more loot in searched containers, finds hidden caches

**Technical & Crafting**
- **Electrical** — hotwiring doors, repairing generators, disabling keycard readers, jury-rigging lights
- **Mechanics** — repairing elevators, ventilation fans, water pumps
- **Metalworking / Welding** — welding doors shut (**the primary base-building action**), cutting through barriers, crafting weapons
- **Carpentry** — barricading with furniture, building barriers
- **Tailoring** — reinforcing clothing (adds bite/scratch protection), crafting bandages
- **Cooking** — safer food, better morale from meals
- **Computers** *(new)* — accessing terminals, decrypting files, interfacing with SCP-079, unlocking doors remotely
- **Security** *(new)* — lockpicking, keycard cloning, disabling alarms, reading camera systems

**XP multiplier sources:**
- **Foundation training manuals** — found in offices; e.g. *"Site Operations Manual Vol. 3: Electrical Systems"* grants ×3 Electrical XP for levels 3–4
- **Orientation VHS tapes** — playable on facility monitors when power is on; grants direct XP. **Playing one makes noise for its full duration.** A brilliant risk/reward: you're standing still, in the light, making noise, to get stronger.

### 10.8 Traits & occupations (character creation)

Point-buy system at run start. Positive traits cost points, negative traits grant them. Start with 0 and balance to ≥0.

**Occupations** (set starting skill levels and grant a signature perk):

| Occupation | Starting skills | Perk |
|---|---|---|
| **Class-D (Unassigned)** | None | +8 trait points. The default hard mode. |
| **Former Medic** | First Aid 3, Biology 1 | Can diagnose infection stage precisely |
| **Former Electrician** | Electrical 3, Mechanics 1 | Can hotwire keycard readers one level above clearance |
| **Former Burglar** | Security 3, Lightfooted 2, Sneaking 2 | Can pick standard mechanical locks |
| **Former Soldier** | Aiming 3, Reloading 2, Fitness 2 | Starts knowing MTF patrol patterns |
| **Former Engineer** | Mechanics 3, Metalworking 2 | Can repair the elevator faster |
| **Former Chemist** | Chemistry 3, Biology 2 | Can synthesize disinfectant from lab supplies |
| **Ex-Foundation Staff** | Computers 3, +L1 clearance card at start | Knows the facility layout (map partially revealed) — **but security shoots you on sight** |
| **Former Athlete** | Fitness 4, Sprinting 3 | Higher stamina ceiling |
| **Former Janitor** | Scavenging 2, Mechanics 1 | **Knows the ventilation network (vents pre-mapped)** |

**Positive traits** (cost points): Strong, Fit, Athletic, Fast Healer, Thick Skinned, Resilient (infection resistance), Iron Gut, Cat Eyes (better dark vision), Light Sleeper (wake on nearby noise), Graceful (quieter), Inconspicuous, Brave (panic resistance), Desensitized (**no panic at all — but no sanity warnings either**), Fast Learner, Organized (+container capacity), Dextrous (faster inventory transfer), Keen Hearing (larger noise-detection radius), Eagle Eyed (spot loot from further), Wakeful, Low Thirst, Steady Hands (**reduced blink rate — enormous for 173**).

**Negative traits** (grant points): Weak, Unfit, Out of Shape, Slow Healer, Thin Skinned, Hemophobic (panic at blood), Claustrophobic (**panic in vents and small rooms**), Nyctophobic (**heavy sanity drain in darkness**), Hard of Hearing, Short Sighted, Clumsy (louder), Conspicuous, Cowardly, Prone to Illness, Slow Learner, Disorganized, Restless Sleeper, High Thirst, Hearty Appetite, Smoker (**nicotine withdrawal causes stress and shaking — and smoking is visible in the dark**), Insomniac, **Twitchy** (increased blink rate — 173 nightmare), **Asthmatic** (loud wheezing after sprinting), **Deaf in One Ear** (directional audio is unreliable).

### 10.9 Inventory, encumbrance & containers

- **Weight-based** (kg), not slot-based. Base capacity from Strength: `8 + strength * 2` kg.
- **Bags** are equipment: plastic bag (2 kg), satchel (8 kg), duffel bag (18 kg), Foundation field pack (25 kg). Wearing a heavy bag increases footstep noise and reduces sprint speed.
- **Encumbrance tiers:** <70% normal · 70–100% slowed, no sprint · >100% severe penalties, cannot run.
- **Containers in the world:** desks, filing cabinets, lockers, medical cabinets, supply crates, vending machines, corpses. Each has a `loot_table` and a **search time** — you must stand still and vulnerable while searching, with an audible rummaging sound.
- **Equipment slots:** head, eyes (goggles/mask), face, neck, torso base, torso outer, hands, belt (quick-access ×4), legs, feet, back (bag), primary hand, secondary hand.

### 10.10 Crafting

Recipe resources in `data/recipes/`. Each declares: inputs (with condition requirements), required tool(s), required skill + level, required workstation, craft time, output, XP granted.

**Category examples:**

| Category | Examples |
|---|---|
| **Medical** | Ripped sheets → bandages · Alcohol + cloth → disinfectant wipes · Needle + thread → suture kit · Metal rod + tape → splint |
| **Weapons** | Pipe + tape + scalpel → improvised spear · Fire extinguisher (blunt, and a smoke screen when discharged) · Rebar club · Molotov (alcohol + rag + lighter) |
| **Tools** | Battery + wire + bulb → improvised lamp · Radio + wire → signal jammer (**blocks 079 door control locally**) · Magnet + wire → keycard reader spoofer |
| **Fortification** | Metal sheet + welder → **welded door** (permanent) · Furniture → barricade · Wire + cans → **noise tripwire alarm** |
| **Chemistry** | Lab reagents → disinfectant, sedative, thermite (**cuts through blast doors**), flashbang |
| **Anomalous** | SCP-914 outputs (§6.5) — the "crafting" system with no recipe list, only experimentation |

**Workstations:** maintenance workbench (Floor 6), chemistry lab (Floor 4), welding station (Floor 5), medical bay (Floor 2). This creates natural hub locations and gives the player a reason to establish a safehouse.

### 10.11 Base building / safehouse

PZ's base building, compressed to a single facility:

- **Weld doors shut** (Metalworking + welder + fuel + metal sheets) — permanent, blocks everything except 106 (phases) and 096 (breaks through).
- **Barricade** doorways and windows with furniture — slows entities, makes noise when broken.
- **Noise tripwires** — wire + cans across a corridor. Alerts you to approach.
- **Light management** — restore power to a zone, or place battery lamps. Light provides sanity and 173-defense but is visible from a distance and draws MTF.
- **Storage** — a safehouse means dumping loot and travelling light.
- **Sleep** — you can only sleep in a location the game considers secured (all entrances welded/barricaded, no anomaly within X meters, not on Floor 7). Sleeping is the *only* way to clear Fatigue, and it advances the world clock: infections progress, 049 converts more corpses, MTF advances.

### 10.12 Sandbox settings

Expose a full sandbox config screen (PZ-style) before starting a run, serialized to `data/sandbox_presets/`. This is cheap to build and enormously extends replay value.

Options: anomaly count multiplier, anomaly aggression, 096 trigger duration, 173 speed, loot abundance (per category), starting clearance, infection lethality, MTF deploy timer, power grid reliability, permadeath on/off, blinking on/off, day length, needs multipliers, save-on-quit vs. **ironman**, and a "**Foundation Standard**" preset (the intended balance) plus "**Class-D Expenditure**" (brutal) and "**Site Tour**" (exploration/no-threat mode for lore readers).

---

## §11 — COMBAT

**Guiding principle: combat is a failure state, not a strategy.** The player should end almost every encounter by running, hiding, or closing a door.

### 11.1 Melee

- Directional swings with real windup, arc, and recovery. Heavy attacks (hold) and light attacks (tap).
- **Stamina-gated.** Three swings and an unfit character is winded.
- **Shove** (PZ's signature) — pushes an entity back and creates space. The most useful combat action in the game.
- Weapon condition degrades; weapons break.
- Melee against 049-2 is viable. Melee against anything else is suicide, and the game should teach this within the first attempt.

### 11.2 Firearms

Scarce, loud, and mostly a mistake.

- Guns: 9 mm sidearm (guards), 5.56 carbine (MTF only), shotgun (armory, L4).
- **Every gunshot is loudness 1.00** and travels the full noise-propagation graph. Firing on Floor 5 will bring 096, 939, and MTF simultaneously.
- Aiming: sway based on Aiming skill, stamina, panic, and injury to the arms/hands. Panic makes precision shooting impossible.
- Ammunition is measured in single rounds, not magazines.
- Guns can kill: 049, 939, 049-2, humans. Guns **cannot** kill: 173, 096 (realistically), 106, 682.

### 11.3 The escape toolkit

The actual "combat system" is the set of tools for *not* fighting:

Doors (close them), blast doors (seal them), lights (turn them off/on), thrown objects (decoy noise), fire extinguishers (smoke screen), ventilation shafts (bypass routes), lockers and under-desks (**hiding spots with a peek mechanic**), SCP-268 (unnoticeability), SCP-1499 (dimensional escape), amnestics (clear cognitohazards), and the femur breaker (recall 106).

---

## §12 — AI ARCHITECTURE

### 12.1 Behavior trees

Implement a lightweight behavior tree in `src/ai/behavior_tree/`. Nodes: `Sequence`, `Selector`, `Parallel`, `Inverter`, `Repeater`, `Cooldown`, `Condition`, `Action`. Each agent has a `Blackboard` (Dictionary) for state.

Trees are defined as `.tres` resources so behavior can be tuned without code changes.

### 12.2 Perception feeding

Every AI agent has `SightSense` and/or `HearingSense` components (§9). They write into the blackboard:

```
last_known_player_position: Vector3
last_seen_time: float
last_heard_position: Vector3
last_heard_loudness: float
threat_level: float
investigating: bool
```

**Investigate, don't teleport.** When an agent hears a noise, it moves to the *last heard position* and searches nearby, then gives up and returns to patrol. Agents must be beatable through misdirection or they aren't fun.

### 12.3 Navigation

Godot `NavigationRegion3D` per floor, baked after generation. Separate nav layers:
- Layer 0: standard walking
- Layer 1: ventilation ducts (player crouched, 939, 1048 only)
- Layer 2: catwalks
- 106 ignores navigation entirely (§7.3)

### 12.4 The Director

`src/autoload/director.gd` — a dynamic pacing system, modeled on Left 4 Dead's AI Director. It tracks a **tension value** and shapes the experience:

```
tension rises from: anomaly proximity, low health, low light, low supplies,
                    time since last safe moment, sanity level
tension falls from: safe rooms, successful escapes, finding supplies, sleep
```

Director responsibilities:
- **Enforce rest beats.** After a high-tension sequence, guarantee 60–120 s of quiet: reroute wandering anomalies away, suppress ambient scares. Sustained terror becomes numbness; the contrast is what scares people.
- **Adjust loot.** If the player has been at <25% health with no medical supplies for >5 minutes, weight the next unopened container toward bandages. Do this invisibly and sparingly.
- **Schedule anomaly encounters.** Anomalies wander, but the Director nudges patrol targets to create near-misses — the entity passes the corridor the player just left. Near-misses are more valuable than encounters.
- **Escalate on inaction.** If the player camps a safe room for >10 minutes, raise alarm level, deploy MTF, or send 106 through the wall. The facility does not wait.

Expose all Director parameters in the sandbox settings, including "Director: Off."

---

## §13 — GRAPHICS & ART PIPELINE

The goal: *"this looks like a real, expensive game."* On an 8 GB RTX 3070 Ti with no artist on the team. This is achievable, and lighting does 70% of the work.

### 13.1 Renderer configuration

Godot 4 **Forward+**, Vulkan. In `project.godot`:

| Setting | Value | Why |
|---|---|---|
| Renderer | Forward+ | Required for SDFGI, SSIL, volumetric fog |
| MSAA 3D | 2× (option up to 4×) | |
| Screen Space AA | FXAA (fallback) | |
| Scaling mode | **FSR 2.2** | Render at 0.77 scale, upscale — big perf win, minimal quality loss |
| SDFGI | On (Medium) | Real-time global illumination; makes interiors look expensive |
| SSAO | On (Medium) | Contact shadows |
| SSIL | On (Low) | Indirect light bounce |
| SSR | On (Low, half-res) | Wet floors, polished surfaces |
| Volumetric Fog | **On** | **The most important setting in the game.** Light shafts through doorways is the entire aesthetic. |
| Glow/Bloom | On, subtle | |
| Shadow atlas | 4096, 4 quadrants | |
| Directional shadows | Off (interior only) | Saves budget |

### 13.2 Lighting — where the "AAA look" actually comes from

- **Almost all light is diegetic.** Fluorescent tubes, emergency strobes, monitor glow, the player's flashlight, sparking wires.
- **`OmniLight3D`/`SpotLight3D` with shadows enabled, but budget carefully:** max 8 shadow-casting lights visible at once. Use non-shadow-casting fill lights liberally — they're nearly free.
- **Bake static lighting** with `LightmapGI` for lights that never move, and keep only dynamic/flickering lights realtime. This is the single biggest perf lever.
- **Emissive materials** for screens, exit signs, and status LEDs — free light-looking detail with zero light cost.
- **Flicker shader** on fluorescents: a broken-tube flicker with an irregular, non-sine pattern. Regular flicker reads as fake.
- **The flashlight is the star.** Cone with a soft falloff, volumetric interaction, slight sway tied to walk cycle and hand injury, battery-driven color temperature shift (white → yellow → amber → dead).

### 13.3 Modular kit strategy

Do not model rooms. Model **kits**, and assemble rooms from them.

**Corridor kit:** wall panel (plain / with conduit / with pipes / with signage), corner, T-junction, doorway frame, floor tile (clean / stained / grated), ceiling panel (solid / light fixture / vent grille / missing), baseboard, pipe runs, cable trays, wall-mounted fire extinguisher/first aid/phone.

**Containment kit:** reinforced wall, observation window, blast door frame, airlock, control panel, warning signage, containment cell interior.

**Lab kit:** bench, fume hood, shelving, sink, centrifuge, microscope, chemical rack, autoclave, gurney.

**Office kit:** desk, chair, cubicle divider, filing cabinet, monitor, keyboard, whiteboard, water cooler, potted plant, wall clock.

Roughly **150–200 unique meshes** builds the entire facility. Generate them with Blender Python scripts (§3.3) for consistency and speed.

### 13.4 Materials — trim sheets

Use **trim sheets**: one 2048×2048 PBR texture set containing many strips of detail (panel lines, grating, rubber trim, rivets, warning stripes), UV-mapped across dozens of meshes. This yields high visual detail at a tiny memory cost, and is exactly how real production art teams work.

Core material set (all from CC0 sources): painted concrete, brushed steel, galvanized steel, epoxy floor, rubber flooring, metal grating, frosted glass, dirty glass, plastic panel, ceramic tile, rust overlay, blood decal, grime overlay.

**Vertex-paint or triplanar-blend grime and rust** onto meshes at assembly time so no two instances of a wall panel look identical.

### 13.5 Characters and animation

- **Rigs:** Use Mixamo-compatible humanoid rigs. Retarget animations in Blender, export as glTF. *(Verify Mixamo's current terms before shipping; if incompatible, use CC0 animation sets from Quaternius/Kenney or record via a free mocap solution.)*
- **Player:** full first-person body with visible arms, legs, and feet — looking down and seeing your own body is a big immersion win and is cheap.
- **SCP models:** the flagship art assets. Budget real time here. 096's proportions (2.38 m, emaciated, absurdly long arms) and 106's decay are the two that must land.
- **Animation quality over quantity.** Ten excellent animations beat forty mediocre ones. Prioritize: idle, walk, run, the 096 trigger-phase collapse, and 106's wall emergence.

### 13.6 Post-processing stack

Custom `.gdshader` post-process layer, applied in this order: SSAO → SSIL → SSR → volumetric fog → bloom → **chromatic aberration (subtle, driven by sanity)** → **film grain (driven by light level — grainier in the dark, like a real sensor)** → vignette (driven by stamina) → color grading LUT per floor → **lens dirt/smudge** → FXAA.

Sanity-driven distortion: as sanity drops, increase chromatic aberration, add a slow breathing warp to the FOV, desaturate the palette, and introduce brief single-frame flashes at the edge of vision.

### 13.7 Performance targets and options

**Target: 60 FPS at 1080p on an RTX 3070 Ti.** Verify with the in-editor profiler each phase.

Graphics options menu: resolution scale (FSR 2.2 slider), shadow quality, SDFGI on/off, SSIL on/off, volumetric fog quality, texture quality, view distance, FOV slider (**70–110, essential for comfort**), motion blur toggle (default off), film grain toggle, chromatic aberration toggle, head-bob intensity, and a **Photosensitivity Mode** that disables strobes and rapid flashing.

**Occlusion culling** must be enabled (`OccluderInstance3D` baked per floor) — an interior game with 80 rooms will die without it.

---

## §14 — AUDIO

Audio is more than half the horror. Budget accordingly.

### 14.1 Bus structure

`Master` → `SFX` (→ `Footsteps`, `Weapons`, `Environment`, `Anomaly`), `Ambience`, `Voice`, `UI`, `Music`

Each bus gets a low-pass filter whose cutoff is driven by wall occlusion between the source and the listener. Sound through a closed door must be genuinely muffled, not just quieter.

### 14.2 Diegetic soundscape

- **Room tone per zone.** Every zone has a unique continuous ambience: fluorescent hum (Floor 1), server fans (Floor 2), HVAC (Floor 3), centrifuges and dripping (Floor 4), distant impacts and metal groan (Floor 5), water and pipes (Floor 6), near-silence with subsonic rumble (Floor 7).
- **The PA system** — automated containment announcements, alarm klaxons, evacuation notices, and (if active) SCP-079's voice. Diegetic exposition.
- **Distance-filtered SCP audio** — 096's scream must be audible from anywhere on the floor, heavily low-passed and reverberant at distance. Hearing it faintly, three rooms away, is the game's best scare and costs nothing.
- **Silence is a tool.** Cutting all ambience for 4 seconds before something happens is more effective than any sting.

### 14.3 Footsteps

Material-based footstep sounds (concrete, grating, tile, water, carpet, glass) × movement state (crouch/walk/run/sprint) × 4 variations = the single highest-value audio investment. The player must be able to identify surfaces by ear.

**NPC and SCP footsteps use the same system** — so you can hear what's approaching and, with practice, identify *what* it is by its gait.

### 14.4 Voice

- 939's voice mimicry (§7.3) requires a runtime clip registry per instance.
- 049's dialogue and 035's dialogue need genuine voice acting. Options: recruit volunteers, use synthesized voices processed heavily (which suits 079 perfectly and is defensible for 035's uncanny quality), or ship subtitled with atmospheric vocalizations only. **Do not ship raw unprocessed TTS for 049** — it will undercut the best-written character in the game.

### 14.5 Music

Minimal. Mostly absent. Use drones, prepared-piano textures, and processed metal resonance rather than melody. Music appears in exactly three contexts: the main menu, an active 096 chase, and the ending. Everything else is silence and room tone.

---

## §15 — UI/UX

**Diegetic-first.** Minimize HUD; make information live in the world.

- **No health bar.** Health is communicated through screen effects, breathing, limping, blood on the hands, and the biomonitor.
- **Biomonitor** (§10.1) — moodle icons in the top-right, presented as a wrist-mounted Foundation device the player can raise to inspect in detail.
- **Inventory** — full-screen, dual-pane (player / container), weight bar, drag-drop, right-click context menus, item condition bars, search-in-progress timers. Model it closely on PZ's; it's the best-in-class design for this.
- **Health panel** — a body diagram with per-part status, PZ-style, with treatment actions per part.
- **Documents** — full-screen reader in an authentic SCP wiki visual style: monospace headers, `Item #:`, `Object Class:`, `Special Containment Procedures:`, black redaction bars over gated spans (§8.1).
- **Journal** — auto-collected documents, an SCP database of everything encountered (unlocking as the player learns), a keycard inventory, and a **hand-drawn-style map** that fills in only where the player has walked (never a satellite view).
- **Terminals** — in-world CRT screens with green phosphor text, an interactive shell, and door controls. Interacting with a terminal draws the camera into it (no cursor-mode swap).
- **Subtitles** — on by default, with speaker names and directional indicators. Full accessibility pass: colorblind modes, text scaling, remappable controls, hold-vs-toggle for every action.

---

## §16 — SAVE SYSTEM & DEATH

### 16.1 What gets saved

Serialize to `user://saves/<slot>/` as JSON (readable for debugging) plus binary for large arrays:

Run seed · current floor · full player state (all components) · complete inventory with condition · every floor's generated layout · every door state · every container's remaining contents · every entity position and blackboard · `FacilityState` (power, alarm, breach registry, 106 corrosion decals) · all corpses with their loot · skill XP and levels · discovered documents and map data · Director tension · elapsed game time.

**Save schema versioning is mandatory from day one.** Include `save_version` and write migration functions. You will change the schema.

### 16.2 Save modes

- **Ironman** (default, PZ-style) — one save, autosaves continuously, deleted on death. This is the intended experience.
- **Checkpoint** — saves on floor transition only.
- **Free save** — save anywhere. For players who want the story.

### 16.3 Death — "This is how you died"

On death, show a Foundation **Termination Report**: your designation, cause of death, floor, time survived, anomalies encountered, documents recovered, and a dry one-line remark from a site administrator.

Then: **the world persists.** A new Class-D is processed into the facility. And:

- **Your corpse remains** exactly where you died, with everything you were carrying.
- If you died on a floor SCP-049 patrols, your corpse **becomes an SCP-049-2 instance** wearing your gear.
- Doors you welded stay welded. Barricades you built stay built. Corrosion 106 left stays.
- Anomalies you released stay released.
- The site's alarm level persists.

This transforms permadeath from a punishment into worldbuilding, and it's the mechanic that will define the game's reputation. **Prioritize it.**

---

## §17 — BUILDING THE `.EXE`

This is the actual deliverable. Get it working in **Phase 0**, before writing gameplay code, and verify it at every phase boundary.

### 17.1 One-time setup

1. Install Godot 4.5+ (.NET build) — the standard build works if not using C#.
2. **Editor → Manage Export Templates → Download and Install.** Without templates, export silently fails.
3. Optionally install **rcedit** (`https://github.com/electron/rcedit/releases`) so Godot can embed the icon and version metadata into the `.exe`.

### 17.2 Export preset

Create a `Windows Desktop` preset in `export_presets.cfg` (commit this file):

```ini
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
export_filter="all_resources"
export_path="build/windows/DEEPWELL.exe"

[preset.0.options]
binary_format/architecture="x86_64"
binary_format/embed_pck=true          # ← CRITICAL: single-file .exe
application/icon="res://assets/icon.ico"
application/file_version="0.1.0.0"
application/product_version="0.1.0.0"
application/company_name="DoperDodge"
application/product_name="Project DEEPWELL"
application/file_description="Project DEEPWELL"
application/copyright="CC BY-SA 3.0"
texture_format/s3tc_bptc=true
```

**`embed_pck=true` is the key setting.** Without it, Godot produces `DEEPWELL.exe` + `DEEPWELL.pck` and the exe won't run without the pck beside it. With it, you get one genuinely standalone executable — exactly what was asked for.

### 17.3 Headless build script

```powershell
# tools/build.ps1
param([string]$Version = "0.1.0")

$ErrorActionPreference = "Stop"
$Godot = "C:\Program Files\Godot\Godot_v4.5-stable_win64.exe"
$Out   = "build\windows\DEEPWELL.exe"

New-Item -ItemType Directory -Force -Path "build\windows" | Out-Null

Write-Host "Importing assets..."
& $Godot --headless --path . --import

Write-Host "Exporting release build..."
& $Godot --headless --path . --export-release "Windows Desktop" $Out

if (-not (Test-Path $Out)) { throw "EXPORT FAILED - no output produced" }

$sizeMB = [math]::Round((Get-Item $Out).Length / 1MB, 1)
Write-Host "OK: $Out ($sizeMB MB)"

# Ship the license alongside — legally required (see PLAN.md §2)
Copy-Item "LICENSE.md"            "build\windows\LICENSE.md"       -Force
Copy-Item "docs\ATTRIBUTION.md"   "build\windows\ATTRIBUTION.md"   -Force
Copy-Item "docs\ASSET_LICENSES.md" "build\windows\ASSET_LICENSES.md" -Force

Write-Host "Build complete."
```

Run with `.\tools\build.ps1`. **If this script fails, the phase is not done.**

### 17.4 Distribution notes

- Unsigned executables trigger **Windows SmartScreen** ("Windows protected your PC"). This is normal for indie builds. For personal use, click "More info → Run anyway." A code-signing certificate (~$100–300/yr from Sectigo/DigiCert) removes it, but is unnecessary here.
- Ship as a `.zip` containing `DEEPWELL.exe`, `LICENSE.md`, `ATTRIBUTION.md`, `ASSET_LICENSES.md`, and a `README.txt`.
- Saves go to `%APPDATA%\Godot\app_userdata\DEEPWELL\` — mention this in the README so players can back them up.
- Expected final size: 2–6 GB depending on texture and audio budget.

### 17.5 Steam (deliberately out of scope)

Publishing is explicitly not a goal. Noted only so the architecture doesn't preclude it: keep all platform-specific code isolated, don't hardcode file paths outside `res://` and `user://`, and if it ever comes up, GodotSteam is the integration path. Note that a CC BY-SA release means anyone who buys it may legally redistribute it for free — so a paid release would be unusual, though legal.

---

## §18 — TESTING & QUALITY

### 18.1 Automated tests

Use **GUT** (Godot Unit Test) in `tests/`. Minimum coverage:

- **Data validation** (`tools/validate_data.gd`, run on every build): every `.tres` in `data/` loads without error; every `id` is unique; every referenced scene/texture path resolves; every recipe's inputs exist as items; every SCP's `floors` array is valid; every document's clearance spans are 0–5.
- **Generation tests:** run `floor_generator` across 500 seeds per floor and assert *every* one produces a valid, completable layout (§6.3 step 3). This test alone will save weeks.
- **Systems tests:** needs decay math, infection stage transitions, encumbrance thresholds, noise propagation attenuation, gaze evaluation with mocked geometry, save→load round-trip fidelity.

### 18.2 Manual playtest protocol

At each phase boundary, play the exported `.exe` (not the editor) for 30 minutes and log in `docs/PLAYTEST_LOG.md`:

1. Did anything crash?
2. Was the framerate stable?
3. Was any death unavoidable/unfair? (**This is the most important question.** Unfair deaths kill this genre.)
4. Did you get lost in a way that was frustrating rather than tense?
5. What was the scariest moment, and why?
6. What was the most boring 60 seconds, and why?

Question 6 matters more than question 5. Boredom is the real failure mode.

### 18.3 Performance budget per frame (1080p, RTX 3070 Ti)

| System | Budget |
|---|---|
| Rendering | 10.0 ms |
| Physics | 2.0 ms |
| AI (all agents) | 1.5 ms |
| Perception (gaze/light/noise) | 1.0 ms |
| Survival simulation | 0.5 ms |
| UI | 1.0 ms |
| **Total** | **16.6 ms (60 FPS)** |

Perception and survival systems must **not** run every frame. Tick them on a staggered scheduler (gaze at 30 Hz, needs at 1 Hz, temperature at 0.5 Hz, noise events immediately). Use `TimeManager` to distribute ticks so they never all land on the same frame.

---

## §19 — MILESTONES

Each phase ends with a working exported `.exe`. Do not begin phase N+1 until phase N's acceptance criteria pass.

### PHASE 0 — Toolchain & skeleton
**Goal:** prove the pipeline end-to-end before writing any game.

- Godot project created, `.gitignore`/`.gitattributes` configured, pushed to GitHub
- Full directory structure from §4 created (empty folders with `.gitkeep`)
- All autoloads registered as empty stubs
- One grey-box room, one cube, one directional light
- `export_presets.cfg` configured with `embed_pck=true`
- `tools/build.ps1` produces a running `DEEPWELL.exe`
- `LICENSE.md` (CC BY-SA 3.0 full text) and `docs/ATTRIBUTION.md` created

**✅ Acceptance:** Double-clicking `build/windows/DEEPWELL.exe` on a machine without Godot installed opens a window showing a lit cube.

### PHASE 1 — Player & interaction
- First-person controller: walk, run, sprint, crouch, jump, lean, stamina
- Mouse look with FOV slider and sensitivity settings
- Full first-person body (visible arms/legs)
- Interaction raycast with prompts ("[E] Open Door", "[E] Search Desk")
- Doors: open/close/locked states, keycard reader stub
- Inventory: pick up, drop, weight, encumbrance tiers, dual-pane UI
- Containers with search timers
- Flashlight with battery drain
- Basic footstep audio with material detection
- Pause menu, options menu, save/load stub

**✅ Acceptance:** Walk a grey-box corridor, open a door, search a desk, pick up a flashlight, get encumbered by carrying too much, save, quit, reload, and find everything where you left it.

### PHASE 2 — Perception & SCP-173
**This is the technical proving phase.** If gaze doesn't feel right, nothing else matters.

- Full gaze system (§9.1) with observation *strength*, frustum + occlusion + cone + light
- Blink system (§9.2) with involuntary blinks and blink pressure
- `LightProbe` sampling (§9.4) with caching
- Noise propagation via navmesh path distance with door attenuation (§9.3)
- **SCP-173** fully implemented: freeze-when-observed, teleport-step when not, instant kill on contact, paint trail
- Debug overlay showing observation strength, noise events, and light levels in real time

**✅ Acceptance:** In a dark grey-box maze, SCP-173 is genuinely terrifying, never moves while observed (verify with the debug overlay across 50 encounters), and creeps at the edge of peripheral vision. Multiple observers correctly stack.

### PHASE 3 — VERTICAL SLICE ⭐ **THE MOST IMPORTANT MILESTONE**
**Goal: a complete, genuinely good small game.** One floor. Everything working. Ship it to yourself and play it repeatedly.

- **Floor 3 (Light Containment)** fully built: 30+ room prefabs, hybrid generation (§6.3), validated across 500 seeds
- Art pass: corridor + containment kits modeled, trim-sheet materials, full lighting pass, volumetric fog
- Survival core: hunger, thirst, fatigue, stamina, health with 12 body parts, bleeding, bandaging, painkillers
- 6 moodles: Hungry, Thirsty, Tired, Endurance, Pain, Bleeding
- SCP-173 + SCP-1048 + SCP-914
- Keycard L1→L2 progression, one stairwell exit
- 15 documents with the redaction system
- Full audio pass on this floor: room tone, footsteps, PA announcements, 173's stone-drag
- Ironman save, death screen, "this is how you died" report
- 8 items, 5 recipes, 1 workstation

**✅ Acceptance:** A person who has never seen this project can launch `DEEPWELL.exe`, play for 30–45 minutes, be scared at least twice, die, understand exactly why they died, and immediately want to try again. **If this criterion isn't met, do not proceed — iterate here.**

### PHASE 4 — Full survival simulation
- All 26 moodles (§10.1)
- Complete injury model: fractures, deep wounds, sutures, splints, burns, glass shards, bandage hygiene
- All three infection tracks (§10.5)
- Nutrition, body weight, fitness (§10.4)
- Temperature, wetness, clothing insulation (§10.6)
- All skills with XP curves, skill books, VHS tapes (§10.7)
- Character creation: occupations + traits, point-buy (§10.8)
- Sleep, safehouse validation
- Full crafting system + all four workstations
- Sandbox settings screen (§10.12)

**✅ Acceptance:** A character can be built from traits, get infected, diagnose it, treat it, fail, and die of sepsis over two in-game days — with the player understanding the causal chain at every step.

### PHASE 5 — Floors 1, 2 & 4
- Entrance Zone, Administration, Research & Testing built and dressed
- Zone-specific kits: office, lab, medical
- SCP-966 + thermal goggles, SCP-049 + 049-2, SCP-035 with dialogue
- Power grid system, zone-based lighting failures
- 40+ additional documents
- Elevator system

**✅ Acceptance:** Continuous playable run from Floor 1 to Floor 5's entrance, ~2.5 hours, with distinct visual identity per floor.

### PHASE 6 — Heavy Containment & the big threats
- Floor 5 & 6 built
- **SCP-096** with the full 90-second trigger phase, photograph triggers, wall-breaking pursuit
- **SCP-939** pack AI with voice mimicry
- **SCP-106** with wall phasing, corrosion persistence, and the pocket dimension
- Ventilation network as a traversable second graph
- Flooding, hypothermia, electrified water
- Generator/power puzzle on Floor 6

**✅ Acceptance:** Each of the three flagship anomalies requires a *different* counterplay strategy, and a skilled player can survive all three consistently while a new player cannot.

### PHASE 7 — Humans, Director & lore depth
- NPC framework: Class-D, guards, researchers, with dialogue and trading
- MTF Epsilon-11 squad AI with coordinated tactics
- SCP-079 with facility control, negotiation, and 24-hour memory
- Director system (§12.4)
- Full document set (60–120), journal, SCP database, map
- Amnestic system

**✅ Acceptance:** The facility feels populated. Escorting a researcher to a stairwell is tense and worthwhile. MTF arrival changes the run's entire character.

### PHASE 8 — Floor 7, endgame & three endings
- Deep Storage / Keter Wing
- SCP-682 scripted set-piece
- Floor 8 "The Well" with reality degradation
- Three endings (§6.6) with generated incident-report epilogue
- Full credits & licensing screen

**✅ Acceptance:** All three endings are reachable and each feels earned.

### PHASE 9 — Polish, balance & accessibility
- Full audio pass on every floor, voice work, dynamic mix
- Post-processing pass, per-floor color grading
- Performance optimization to hit the §18.3 budget
- Accessibility: colorblind modes, subtitle options, remapping, photosensitivity mode, difficulty presets
- Balance pass driven by playtest telemetry
- Localization scaffolding (all strings externalized to `.csv` from Phase 1 — **do this from the start, not now**)

**✅ Acceptance:** 60 FPS sustained at 1080p on the target GPU. No unfair deaths in a 3-hour playtest. Every string is externalized.

### PHASE 10 — Stretch (only after Phase 9 ships)
- Co-op multiplayer (§20.6)
- Additional floors / alternate site layouts
- Mod support (load `.tres` from `user://mods/`)
- New game+ with persistent facility state

---

## §20 — ORIGINAL DESIGN ADDITIONS

Ideas beyond the brief, ranked by value-to-effort. **The first four are the ones that will define this game.**

### 20.1 ⭐ Your corpse becomes the enemy
Covered in §16.3 and §7.3. When you die on Floor 4, SCP-049 converts your body into an 049-2 wearing your gear. Your next character finds it. This single mechanic makes permadeath *generative* rather than punitive, and no other SCP game does it.

### 20.2 ⭐ Documents that kill you
SCP-096's trigger works through photographs. Place its face inside a document, on a monitor, in a personnel file. A player who reads the wrong file in a locked, safe office triggers a 96-second countdown from three floors away. **The Foundation's own bureaucracy is the murder weapon.** Thematically perfect and mechanically unforgettable.

### 20.3 ⭐ Progressive declassification
§8.1. Every document is authored at Level-5 detail, redacted down to your clearance. Finding an L4 card retroactively rewrites 60 documents you already read. Story progression and mechanical progression are the same axis.

### 20.4 ⭐ NPCs as tools, not obstacles
A living guard looking at SCP-173 freezes it *for you*. Keeping an NPC alive and positioned becomes a real tactic. A screaming researcher is 939 bait. This turns every NPC into a resource with a moral cost.

### 20.5 The Anomaly Log
An in-game database that fills in as you observe. First encounter with 173 logs "Entity moves when unobserved — unverified." After ten encounters it upgrades to a full containment procedure. **The player character is doing science.** Completing the log is a genuine second progression axis and a reason to take risks.

### 20.6 Co-op multiplayer (2–4, stretch)
Godot's high-level multiplayer API over ENet. The SCP setting is *built* for co-op:
- **Proximity voice chat** — and 939 mimics your friends' actual recorded voices
- **173 requires someone to keep watching it** while others work — the single best co-op mechanic available in any horror premise
- **096's trigger is per-player** — one person looks, everyone dies
- Split clearance: different players carry different keycards
- **Betrayal is possible.** One keycard, one exit.

Substantial work (2–3 months). Do not attempt before Phase 9.

### 20.7 The Site is running out of time
A global timer the player never sees directly. Every hour: MTF advances a floor, 049 converts more corpses, power grid degrades, more doors auto-seal. The environment tells you: distant gunfire moves closer, PA announcements escalate, corridors you cleared refill. **Nothing in the HUD.** The player feels the pressure without being told.

### 20.8 Dynamic containment cascade
Breaching one anomaly increases facility alert level, which auto-opens certain doors as an emergency protocol — which breaches more anomalies. A player who breaks something on Floor 3 finds Floor 5 dramatically worse. Every breach is logged to a facility incident report the player can find later, describing their own actions in dry Foundation prose.

### 20.9 Radio contact
A handheld radio picks up transmissions from other survivors. They give real information ("don't go through the east wing"), ask for help, and die on-air. One of them is lying. One of them is 939.

### 20.10 The vents are a second map
The ventilation network is a genuine parallel navigation layer with its own risks: crawl speed only, no weapons usable, claustrophobia trait penalty, sound propagates *further* in ducts (×0.85 vs ×0.4 through doors), and 939 and 1048 can follow you in. The Former Janitor occupation starts with them mapped.

### 20.11 The Interview Transcripts
Scattered audio logs of Foundation researchers interviewing 049, 035, and 079. Not exposition dumps — genuine, well-written character work, played diegetically on a recovered tape recorder. The recorder must be held (occupying a hand slot) and is audible to entities. **You have to choose between knowing the story and being safe.**

### 20.12 Fatigue as unreliable narration
At extreme fatigue, the game begins showing things that aren't there: a figure at the end of a corridor that vanishes, a door that was open, footsteps behind you. These are *not* cognitohazards and there's no cure but sleep. The player can never fully trust their own senses, and it's mechanically honest because sleep always fixes it.

### 20.13 Seeded run sharing
Because generation is deterministic (§5.5), the death screen shows a seed code. "Try seed 8F2A-91C3, I lasted 40 minutes." Nearly free to implement, enormous for community engagement.

---

## §21 — ANTI-PATTERNS: WHAT NOT TO DO

**Technical**
- ❌ Do **not** build this as an HTML/JavaScript/canvas game. Native Godot → `.exe`. This is a hard requirement.
- ❌ Do **not** put game logic in `.tscn` files. Scenes are presentation; scripts in `src/` are logic; `data/` is content.
- ❌ Do **not** hardcode content in scripts. New SCP = new `.tres`, zero code changes.
- ❌ Do **not** use direct node references between systems. Everything goes through `EventBus`.
- ❌ Do **not** call `randi()` or `randf()`. Use `RNG.stream()` — determinism is load-bearing.
- ❌ Do **not** run perception, needs, or temperature every frame. Stagger the ticks.
- ❌ Do **not** skip the export step at a phase boundary. In-editor success is not success.
- ❌ Do **not** write "TODO: implement later." Ship a working minimal version instead.

**Legal**
- ❌ Do **not** model SCP-173 on Izumi Kato's sculpture (§2.3). Original designs only.
- ❌ Do **not** copy *any* image from the SCP wiki. Use article text; create original art.
- ❌ Do **not** import any CC-NC or CC-ND asset. It poisons the entire release.
- ❌ Do **not** skip `docs/ATTRIBUTION.md`. It is a license requirement, not a courtesy.

**Design**
- ❌ Do **not** make anomalies fightable. The moment 173 has a health bar, the game is dead.
- ❌ Do **not** use loud-noise jumpscares as a primary tool. Build dread; use silence.
- ❌ Do **not** create unavoidable deaths. Every death must have had a visible, learnable warning. This is the #1 cause of players quitting survival horror.
- ❌ Do **not** generate rooms procedurally from scratch. Hand-authored prefabs, procedural assembly.
- ❌ Do **not** create tree-shaped (loopless) layouts. Dead ends produce unfair deaths.
- ❌ Do **not** explain mechanics in tutorial popups. Teach through the environment and through death.
- ❌ Do **not** put a minimap with live enemy positions on screen. It destroys every system in §9.
- ❌ Do **not** let the player carry everything. Encumbrance is a core tension.
- ❌ Do **not** make the first floor scary. Floor 1 is quiet on purpose — the contrast is what makes Floor 3 land.

---

## §22 — APPENDIX A: THE FIRST TWENTY TASKS

For the implementing agent, in strict order:

1. Install Godot 4.5+, create the project, set the renderer to Forward+
2. Create the full §4 directory structure with `.gitkeep` files
3. `git init`, write `.gitignore` (`.godot/`, `build/`, `*.tmp`) and `.gitattributes` (LFS for `*.glb *.png *.ogg *.wav *.jpg`), push to GitHub
4. Write `LICENSE.md` with the full CC BY-SA 3.0 text
5. Write `docs/ATTRIBUTION.md` with the §2.2 boilerplate and an empty SCP table
6. Create all eight autoload stubs; register them in `project.godot` in the §5.1 order
7. Write `src/autoload/event_bus.gd` with the complete signal list from §5.2
8. Write `src/util/rng.gd` with seeded streams (§5.5)
9. Build a grey-box test room: 20×20 m, 3.2 m ceiling, four walls, one omni light
10. Configure `export_presets.cfg` with `embed_pck=true` (§17.2)
11. Write `tools/build.ps1` (§17.3) and **verify a standalone `.exe` runs on a machine without Godot**
12. ⬅ **PHASE 0 COMPLETE — commit and tag `v0.0.1-phase0`**
13. Write `src/player/player.gd` — `CharacterBody3D`, capsule 0.4 m × 1.8 m, eye height 1.65 m
14. Write `src/player/player_movement.gd` — walk 2.2 m/s, run 4.0 m/s, sprint 6.0 m/s, crouch 1.1 m/s, with a stamina pool
15. Write `src/player/player_camera.gd` — mouse look, FOV slider, head-bob (intensity option), lean
16. Write `src/player/player_interaction.gd` — 2.5 m raycast, `Interactable` interface, prompt UI
17. Write `src/facility/door.gd` with all six door states (§6.4) and `src/facility/keycard_reader.gd`
18. Write `src/items/item_definition.gd` (§5.3) and create three test items as `.tres`
19. Write `src/inventory/inventory.gd` — weight-based, encumbrance tiers, signals to `EventBus`
20. Build the dual-pane inventory UI and the container search-timer interaction

Then continue through Phase 1's acceptance criteria (§19).

---

## §23 — APPENDIX B: KEY BALANCE CONSTANTS

Start here; tune from playtest data. All values are per real-time second unless noted, at 1× sandbox multipliers.

```gdscript
# --- Movement (m/s) ---
const SPEED_CROUCH        := 1.1
const SPEED_WALK          := 2.2
const SPEED_RUN           := 4.0
const SPEED_SPRINT        := 6.0
const SPEED_VENT_CRAWL    := 0.9

# --- Stamina ---
const STAMINA_MAX_BASE    := 100.0   # + fitness * 15
const STAMINA_SPRINT_COST := 12.0    # per second
const STAMINA_REGEN       := 6.0     # per second, only when not sprinting
const STAMINA_REGEN_DELAY := 1.5     # seconds after exertion stops

# --- Needs (per in-game hour; 1 game hour = 90 real seconds default) ---
const HUNGER_RATE         := 1.4
const THIRST_RATE         := 2.1
const FATIGUE_RATE        := 4.2
const BOREDOM_RATE        := 3.0

# --- Health ---
const HEALTH_PER_PART     := 100.0
const BLEED_LIGHT         := 0.4     # HP/sec
const BLEED_HEAVY         := 1.8
const BLEED_ARTERIAL      := 5.0
const FRACTURE_SPEED_MULT := 0.5

# --- Infection ---
const PESTILENCE_DURATION_HOURS := 6.0
const WOUND_INFECT_RATE   := 0.8     # per hour, untreated
const SEPSIS_THRESHOLD    := 75.0

# --- Blinking ---
const BLINK_INTERVAL_MIN  := 4.0
const BLINK_INTERVAL_MAX  := 8.0
const BLINK_DURATION      := 0.15
const BLINK_FORCED_DURATION := 0.40

# --- SCP-173 ---
const SCP173_STEP_DISTANCE := 4.0    # meters per unobserved step
const SCP173_STEP_COOLDOWN := 0.12   # seconds between steps

# --- SCP-096 ---
const SCP096_TRIGGER_DURATION := 90.0   # seconds — DO NOT SHORTEN
const SCP096_CHASE_SPEED      := 11.0   # m/s — unoutrunnable by design
const SCP096_DOOR_BREAK_TIME  := 3.0    # standard door
const SCP096_WALL_BREAK_TIME  := 8.0    # drywall only; not concrete

# --- SCP-106 ---
const SCP106_SPEED             := 1.6   # slow, but it goes through walls
const SCP106_POCKET_TIME_LIMIT := 180.0 # seconds to escape

# --- SCP-939 ---
const SCP939_SPEED_PATROL := 1.8
const SCP939_SPEED_CHASE  := 7.5
const SCP939_HEARING_M    := 45.0    # effective at loudness 1.0

# --- Inventory ---
const CARRY_BASE_KG       := 8.0     # + strength * 2.0
const ENCUMBER_SLOW       := 0.70    # fraction of capacity
const ENCUMBER_SEVERE     := 1.00

# --- Noise falloff ---
const NOISE_FALLOFF_CONST := 18.0    # meters; exp(-dist / this)
const ATTEN_DOOR_CLOSED   := 0.40
const ATTEN_BLAST_DOOR    := 0.05
const ATTEN_VENT          := 0.85    # vents carry sound FURTHER
const ATTEN_WATER         := 0.60
```

---

## §24 — QUICK REFERENCE CARD

| Question | Answer |
|---|---|
| Engine? | Godot 4.5+, Forward+ renderer |
| Language? | GDScript (C# only for profiled hot paths) |
| Output? | Single standalone `DEEPWELL.exe` (`embed_pck=true`) |
| License? | **CC BY-SA 3.0 — mandatory, viral, non-negotiable** |
| Biggest legal trap? | SCP-173's image is copyrighted (Izumi Kato). Original models only. |
| Hardest technical problem? | The gaze/observation system (§9.1). Get it right in Phase 2. |
| Most important milestone? | **Phase 3, the vertical slice.** One great floor before eight mediocre ones. |
| Most important design rule? | Every death must be learnable. No unavoidable deaths, ever. |
| Best single mechanic? | Your corpse becomes an SCP-049-2 wearing your gear (§20.1). |
| Where does content live? | `data/**/*.tres` — never in scripts |
| How do systems talk? | `EventBus` signals only — never direct references |
| Where does randomness come from? | `RNG.stream(name)` — never `randi()` |

---

*Project DEEPWELL — master implementation plan.*
*Content relating to the SCP Foundation is licensed under CC BY-SA 3.0; all concepts originate from https://scpwiki.com and its authors. This document and any work derived from it are released under the same license.*
