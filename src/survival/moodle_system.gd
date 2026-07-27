## Computes active moodles from player stats at 1 Hz (PLAN §10.1).
## The HUD renders these as the Foundation biomonitor readout.
class_name MoodleSystem
extends Node

const MOODLES_DIR := "res://data/moodles"

var defs: Array[MoodleDefinition] = []
var levels: Dictionary = {} # StringName -> int

func _ready() -> void:
	_load_defs()
	TimeManager.register_tick(_tick, 1.0)

func _load_defs() -> void:
	var dir := DirAccess.open(MOODLES_DIR)
	if dir == null:
		push_warning("MoodleSystem: no moodle definitions found")
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var base := fname.trim_suffix(".remap")
			if base.ends_with(".tres") or base.ends_with(".res"):
				var def := load(MOODLES_DIR + "/" + base) as MoodleDefinition
				if def != null and def.id != &"":
					defs.append(def)
		fname = dir.get_next()
	defs.sort_custom(func(a: MoodleDefinition, b: MoodleDefinition) -> bool: return str(a.id) < str(b.id))

func _tick() -> void:
	var player := get_parent()
	if player == null or not player.has_method("get_stat"):
		return
	for def in defs:
		var value: float = player.get_stat(def.stat)
		var new_level := def.level_for(value)
		var old_level: int = levels.get(def.id, 0)
		if new_level != old_level:
			levels[def.id] = new_level
			EventBus.moodle_changed.emit(def.id, new_level)

## [{def: MoodleDefinition, level: int}] for every active moodle.
func active() -> Array:
	var out := []
	for def in defs:
		var lv: int = levels.get(def.id, 0)
		if lv > 0:
			out.append({"def": def, "level": lv})
	return out

func level_of(id: StringName) -> int:
	return levels.get(id, 0)
