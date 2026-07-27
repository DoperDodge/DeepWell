# PROJECT DEEPWELL

You are D-9341, a Class-D test subject in an SCP Foundation deep-storage site
during a cascading containment failure. The only way out is down.

A first-person survival-horror sim: *SCP – Containment Breach* structure ×
*Project Zomboid* systemic depth. Built in **Godot 4.5** (Forward+), released
under **CC BY-SA 3.0** (see [LICENSE.md](LICENSE.md) — this is a license
requirement of SCP content, not a choice).

**Current build: the Phase 3 vertical slice** — Floor 3 (Light Containment),
procedurally assembled and fully playable: survival needs, body-part medical
system, biomonitor moodles, redacted documents, SCP-173, SCP-1048, SCP-914,
ironman permadeath, and a persistent site where your corpses stay where they
fell, holding everything they carried. See [PLAN.md](PLAN.md) for the full
design and the phase roadmap.

## Running it

**Prebuilt:** run `DEEPWELL.exe` (Windows) from a release build — it is a
single self-contained file.

**From source:**
1. Install [Godot 4.5+](https://godotengine.org/download) (standard build).
2. Open this folder ( `project.godot` ) and press F5 — or run
   `godot --path .` from the repository root.

**Export a build:**
1. In Godot: *Editor → Manage Export Templates → Download and Install* (or
   place templates under the user templates folder).
2. `./tools/build.sh windows` (Linux/macOS host) or `.\tools\build.ps1`
   (Windows host, PowerShell). Output lands in `build/`.

## Controls

| Input | Action |
|---|---|
| WASD / mouse | Move / look |
| Shift | Sprint (loud; drains stamina) |
| C or Ctrl | Crouch (quiet) |
| Q / R | Lean left / right |
| E | Interact (hold for searches and prying) |
| F | Flashlight |
| Tab or I | Inventory |
| J | Journal (documents, anomaly log, site log) |
| B | Blink voluntarily |
| Hold RMB | Keep your eyes open (blink pressure builds) |
| Space | Jump |
| Esc | Pause / close screens |
| F3 | Debug overlay |

Three field notes: **blinking is real** and SCP-173 knows it; **sound is
simulated** through doors and corridors, and everything hostile navigates by
it; **doors close behind you** for a reason.

## Seeds and the persistent site

Every run has a seed code (shown on the death report, e.g. `8F2A-91C3`).
The same seed is the same site: same layout, same loot — and the same
history. Dying does not reset a site. Your body stays where it dropped with
everything it carried, the next D-Class number is processed in, and the
incident log grows. Enter a friend's seed on the main menu to attempt the
site that killed them.

## Development

- `tools/check.sh` — headless validation: script compile, data schema
  checks, a 60-seed generation soak with determinism verification.
- `godot --headless --path . -- --smoke` — full gameplay loop test:
  doors, loot, documents, SCP-914, saves, and a scripted SCP-173 kill with
  corpse persistence.
- Architecture and data formats: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md),
  [docs/DATA_SCHEMAS.md](docs/DATA_SCHEMAS.md).
- Licensing and per-article SCP credits: [docs/ATTRIBUTION.md](docs/ATTRIBUTION.md)
  — read this before adding any SCP content or any asset.

## License

CC BY-SA 3.0 — the whole project, code and content. Content relating to the
SCP Foundation originates from <https://scpwiki.com> and its authors; all
visual designs here are original (notably SCP-173 — see the Izumi Kato
notice in `docs/ATTRIBUTION.md`).
