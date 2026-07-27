## Per-floor generation parameters (PLAN §6.1-6.3).
## Content lives in data/floors/floor_N.tres.
class_name FloorDef
extends Resource

@export var floor_index: int = 3
@export var zone_name: String = "Light Containment"
@export var grid_width: int = 34
@export var grid_height: int = 34
## Target number of placed rooms (mandatory specials always place).
@export var target_rooms: int = 22
## Fraction of extra corridor links beyond the spanning tree — loops are
## ESSENTIAL (PLAN §6.3: dead ends mean unfair deaths).
@export var extra_link_fraction: float = 0.22
@export var ambient_light: float = 0.05
@export var ambience_sound: StringName = &"drone_lcz"
@export var corridor_light_spacing: int = 3
@export var corridor_broken_light_chance: float = 0.4
@export var light_color: Color = Color(0.92, 0.95, 1.0)
## Structural tint: multiplies wall/floor material colors for zone identity.
@export var wall_tint: Color = Color(1, 1, 1)
@export var fog_density: float = 0.028
## The stairwell interact label, e.g. "Descend to Floor 4".
@export var exit_label: String = "Descend"
## The last playable floor: its exit rolls the ending instead of descending.
@export var final_floor: bool = false
## SCPs active on this floor (script paths resolved by the generator).
@export var scp_spawns: Array[StringName] = []
## Clearance required at the exit stairwell.
@export var exit_clearance: int = 2
## PA lines the facility voice rotates through on this floor.
@export var pa_lines: Array[String] = []
