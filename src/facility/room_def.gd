## Metadata for one room prefab (PLAN §6.3). Content lives in
## data/room_prefabs/*.tres; geometry is assembled by RoomBuilder from the
## style + size here (no hand-modeled scenes in this repo — see
## docs/ARCHITECTURE.md).
class_name RoomDef
extends Resource

@export var id: StringName
@export var display_name: String
## Footprint in 4 m grid cells.
@export var size_w: int = 3
@export var size_h: int = 3
## Dressing style: "office" | "storage" | "containment_cell" | "lab" |
## "break_room" | "checkpoint" | "corridor_hub" | "empty" | "machine_room"
@export var style: String = "empty"
## Unique placement role: "" | "spawn" | "stairwell" | "keycard_office" |
## "scp_173_chamber" | "scp_914"
@export var special: String = ""
@export var tags: Array[StringName] = []
## Which floors this room may appear on (PLAN §6.2 — every floor distinct).
@export var floors: Array[int] = [3]
@export var weight: float = 1.0
@export var max_instances: int = 3
## Clearance needed at this room's doors. 0 = unlocked.
@export var door_clearance: int = 0
## Chance any given door spawns POWERED_DOWN instead of locked (pry path).
@export var powered_down_chance: float = 0.0

@export_group("Dressing")
@export var containers_min: int = 0
@export var containers_max: int = 2
## Loot table id rolled for containers in this room.
@export var loot_table: StringName = &"generic"
@export var documents_min: int = 0
@export var documents_max: int = 1
@export var light_color: Color = Color(0.95, 0.97, 1.0)
## Chance each light is broken/flickering (Floor 3: power failures begin).
@export var broken_light_chance: float = 0.35
@export var corpse_chance: float = 0.0
