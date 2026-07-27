# Asset license register

Every third-party file imported into this repository must be recorded here
with its source URL, author, and license, **before** it is committed.
Licenses must be compatible with a CC BY-SA 3.0 release (see PLAN.md §2.4):
CC0, CC BY 3.0/4.0, CC BY-SA 3.0 are safe; **CC BY-NC, CC BY-ND, and
"free for personal use" assets are forbidden.**

## Current register

| File | Source | Author | License |
|---|---|---|---|
| *(none)* | — | — | — |

This project currently contains **zero third-party assets**:

- **Geometry** — generated at runtime from Godot primitive meshes by
  `src/facility/room_builder.gd` and the entity scripts (see
  `docs/ARCHITECTURE.md`).
- **Audio** — synthesized procedurally at startup by
  `src/autoload/audio_manager.gd` (noise bursts, filtered drones, sine
  sweeps). No recorded samples.
- **Textures** — flat PBR parameters plus Godot's built-in `FastNoiseLite`
  procedural noise. No image files.
- **Fonts** — Godot's built-in default font.
- **Icon** — `icon.svg`, original work, CC BY-SA 3.0 like the rest of the
  repository.

If you replace the procedural placeholders with real assets (Poly Haven,
ambientCG, Kenney, Quaternius, CC0 Freesound, etc.), record every file here
and enable Git LFS first (see `.gitattributes`).
