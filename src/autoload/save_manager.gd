## Run serialization (PLAN §16). JSON at user://saves/ — readable on purpose.
## Layout is NOT saved: it regenerates deterministically from the seed, then
## state diffs (door states, container contents, entity positions) are
## applied on top. Save schema is versioned from day one.
extends Node

const SAVE_DIR := "user://saves"
const SAVE_PATH := "user://saves/run.json"
const SAVE_VERSION := 1
const AUTOSAVE_INTERVAL := 45.0

var _pending_apply: Dictionary = {} # held between load_run() and floor ready

func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.player_died.connect(_on_player_died)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func read_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", -1)) != SAVE_VERSION:
		push_warning("SaveManager: incompatible save version, ignoring")
		return {}
	return d

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func save_run() -> void:
	if not GameState.run_active or GameState.player == null:
		return
	var player: Node = GameState.player
	if not player.has_method("serialize"):
		return
	var scps := {}
	for n in get_tree().get_nodes_in_group(&"persistable"):
		if n.has_method("serialize_state") and "persist_id" in n:
			scps[str(n.persist_id)] = n.serialize_state()
	var data := {
		"version": SAVE_VERSION,
		"seed": GameState.run_seed,
		"floor": GameState.floor_index,
		"designation": GameState.designation,
		"occupation": str(GameState.occupation),
		"traits": GameState.traits,
		"clearance": GameState.clearance,
		"journal": GameState.journal,
		"sandbox": GameState.sandbox,
		"stats": GameState.stats,
		"time": TimeManager.serialize(),
		"facility": FacilityState.serialize_run(),
		"player": player.serialize(),
		"entities": scps,
	}
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: cannot write save file")
		return
	f.store_string(JSON.stringify(data, "\t"))

## Called by main.gd before regenerating the floor for a resumed run.
func stage_loaded_state(data: Dictionary) -> void:
	_pending_apply = data
	FacilityState.deserialize_run(data.get("facility", {}))
	TimeManager.deserialize(data.get("time", {}))
	GameState.designation = data.get("designation", GameState.designation)
	GameState.occupation = StringName(data.get("occupation", "unassigned"))
	GameState.traits = data.get("traits", [])
	GameState.clearance = int(data.get("clearance", 0))
	GameState.journal = data.get("journal", {})
	GameState.sandbox = data.get("sandbox", GameState.sandbox)
	GameState.stats = data.get("stats", GameState.stats)

## Called by main.gd after the floor and player exist.
func apply_staged_state() -> void:
	if _pending_apply.is_empty():
		return
	var data := _pending_apply
	_pending_apply = {}
	var player: Node = GameState.player
	if player != null and player.has_method("deserialize"):
		player.deserialize(data.get("player", {}))
	var entities: Dictionary = data.get("entities", {})
	for n in get_tree().get_nodes_in_group(&"persistable"):
		if n.has_method("deserialize_state") and "persist_id" in n:
			var st: Variant = entities.get(str(n.persist_id))
			if typeof(st) == TYPE_DICTIONARY:
				n.deserialize_state(st)

func _on_run_started(_seed_value: int) -> void:
	TimeManager.register_tick(_autosave_tick, AUTOSAVE_INTERVAL)

func _autosave_tick() -> void:
	if GameState.sandbox.get("ironman", true):
		save_run()

func _on_player_died(_cause: String, _floor_index: int, _pos: Vector3) -> void:
	# Ironman: death deletes the run. The site file (corpses, welded doors,
	# incident log) survives — that's the point.
	delete_save()
