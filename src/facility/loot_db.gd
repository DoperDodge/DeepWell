## Registry of LootTable resources from data/loot_tables/.
class_name LootDB
extends RefCounted

const DIR := "res://data/loot_tables"

static var _tables: Dictionary = {}
static var _loaded := false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_error("LootDB: cannot open " + DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var base := fname.trim_suffix(".remap")
			if base.ends_with(".tres") or base.ends_with(".res"):
				var t := load(DIR + "/" + base) as LootTable
				if t != null and t.id != &"":
					_tables[t.id] = t
		fname = dir.get_next()

static func get_table(id: StringName) -> LootTable:
	_ensure()
	return _tables.get(id)

static func all_ids() -> Array:
	_ensure()
	return _tables.keys()
