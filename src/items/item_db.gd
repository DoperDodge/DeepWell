## Loads every ItemDefinition in data/items/ into an id-keyed registry.
## Static, lazy, immutable after first access.
class_name ItemDB
extends RefCounted

const ITEMS_DIR := "res://data/items"

static var _defs: Dictionary = {} # StringName -> ItemDefinition
static var _loaded := false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_error("ItemDB: cannot open " + ITEMS_DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			# Exported builds convert .tres to .res and list remaps.
			var base := fname.trim_suffix(".remap")
			if base.ends_with(".tres") or base.ends_with(".res"):
				var res := load(ITEMS_DIR + "/" + base)
				var def := res as ItemDefinition
				if def == null:
					push_error("ItemDB: not an ItemDefinition: " + base)
				elif def.id == &"":
					push_error("ItemDB: missing id in " + base)
				elif _defs.has(def.id):
					push_error("ItemDB: duplicate id " + def.id)
				else:
					_defs[def.id] = def
		fname = dir.get_next()

static func get_def(id: StringName) -> ItemDefinition:
	_ensure()
	return _defs.get(id)

static func all_ids() -> Array:
	_ensure()
	return _defs.keys()

static func exists(id: StringName) -> bool:
	_ensure()
	return _defs.has(id)
