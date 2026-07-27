## Headless project validation (PLAN §18.1). Run via tools/check.sh:
##   godot --headless --path . -- --validate
## main.gd instantiates this node instead of the menu when --validate is
## passed (autoloads are only available inside a real project run). Loads
## every script and resource, checks data schemas, soaks the floor generator
## across many seeds, and round-trips serialization.
extends Node

var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	_run()

func _run() -> void:
	_check_scripts()
	_check_items()
	_check_moodles()
	_check_loot_tables()
	_check_rooms_and_floor()
	_check_documents()
	_check_audio()
	_soak_generator(60)
	_check_save_roundtrip()

	if _failures.is_empty():
		print("VALIDATION OK — all checks passed")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("FAIL: " + f)
		print("VALIDATION FAILED — %d problem(s)" % _failures.size())
		get_tree().quit(1)

func _fail(msg: String) -> void:
	_failures.append(msg)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)

# ------------------------------------------------------------ checks

func _check_scripts() -> void:
	var count := 0
	for path in _walk("res://src", ".gd") + _walk("res://tools", ".gd"):
		if path.ends_with("validate_project.gd"):
			continue
		var script := load(path) as GDScript
		if script == null:
			_fail("script failed to load: " + path)
			continue
		if not script.can_instantiate():
			_fail("script cannot instantiate (compile error): " + path)
		count += 1
	print("scripts checked: %d" % count)

func _check_items() -> void:
	var ids := ItemDB.all_ids()
	_check(ids.size() >= 20, "expected >= 20 items, found %d" % ids.size())
	for id in ids:
		var def := ItemDB.get_def(id)
		_check(def.display_name != "", "item %s missing display_name" % id)
		_check(def.weight_kg > 0.0, "item %s has non-positive weight" % id)
		for target in [def.upgrade_result, def.refine_result, def.downgrade_result]:
			if target != &"":
				_check(ItemDB.exists(target), "item %s references missing item %s" % [id, target])
	# SCP-914 anomalous outputs must exist.
	for out_id in SCP914.ANOMALOUS_OUTPUTS:
		_check(ItemDB.exists(out_id), "914 anomalous output missing: %s" % out_id)
	print("items checked: %d" % ids.size())

func _check_moodles() -> void:
	var count := 0
	var seen := {}
	for path in _walk("res://data/moodles", ".tres"):
		var def := load(path) as MoodleDefinition
		if def == null:
			_fail("not a MoodleDefinition: " + path)
			continue
		_check(not seen.has(def.id), "duplicate moodle id %s" % def.id)
		seen[def.id] = true
		_check(def.thresholds.size() == 4, "moodle %s needs 4 thresholds" % def.id)
		for i in range(1, def.thresholds.size()):
			_check(def.thresholds[i] > def.thresholds[i - 1], "moodle %s thresholds not ascending" % def.id)
		count += 1
	_check(count >= 12, "expected >= 12 moodles, found %d" % count)
	print("moodles checked: %d" % count)

func _check_loot_tables() -> void:
	var ids := LootDB.all_ids()
	for id in ids:
		var table := LootDB.get_table(id)
		for e in table.entries:
			var item_id := StringName(e.get("item", ""))
			_check(ItemDB.exists(item_id), "loot table %s references missing item %s" % [id, item_id])
	_check(ids.size() >= 8, "expected >= 8 loot tables, found %d" % ids.size())
	print("loot tables checked: %d" % ids.size())

func _check_rooms_and_floor() -> void:
	var specials := {}
	var count := 0
	for path in _walk("res://data/room_prefabs", ".tres"):
		var def := load(path) as RoomDef
		if def == null:
			_fail("not a RoomDef: " + path)
			continue
		_check(def.size_w >= 2 and def.size_h >= 2, "room %s too small" % def.id)
		if def.special != "":
			specials[def.special] = true
		if def.loot_table != &"":
			_check(LootDB.get_table(def.loot_table) != null, "room %s references missing loot table %s" % [def.id, def.loot_table])
		count += 1
	for s in ["spawn", "stairwell", "keycard_office", "scp_173_chamber", "scp_914"]:
		_check(specials.has(s), "missing special room: " + s)
	var floor_def := load("res://data/floors/floor_3.tres") as FloorDef
	_check(floor_def != null, "floor_3.tres missing or invalid")
	if floor_def != null:
		for scp in floor_def.scp_spawns:
			_check(ResourceLoader.exists("res://src/scps/%s.gd" % scp), "floor references missing SCP script %s" % scp)
	print("rooms checked: %d" % count)

func _check_documents() -> void:
	var ids := DocumentDB.all_ids()
	_check(ids.size() >= 15, "expected >= 15 documents, found %d" % ids.size())
	for id in ids:
		var doc := DocumentDB.get_doc(id)
		_check(doc.get("title", "") != "", "document %s missing title" % id)
		var body: Array = doc.get("body", [])
		_check(body.size() > 0, "document %s has empty body" % id)
		for span in body:
			var c := int(span.get("clearance", 0))
			_check(c >= 0 and c <= 5, "document %s has out-of-range clearance %d" % [id, c])
		# Rendering must not crash at any clearance.
		for clearance in 6:
			var text := GameUI.render_document(doc, clearance)
			_check(text.length() > 0, "document %s renders empty at clearance %d" % [id, clearance])
	_check(DocumentDB.docs_for_floor(3).size() >= 12, "floor 3 needs >= 12 placed documents")
	print("documents checked: %d" % ids.size())

func _check_audio() -> void:
	for sound in [&"footstep_concrete_0", &"door_open", &"door_close", &"stone_drag",
			&"neck_snap", &"drone_lcz", &"heartbeat", &"machine_run", &"squeak", &"pa_chime"]:
		_check(AudioManager.has_sound(sound), "missing synthesized sound %s" % sound)
	print("audio library checked")

## Generation soak (PLAN §18.1): every seed must produce a valid floor, and
## the same seed must produce the identical layout twice (determinism §5.5).
func _soak_generator(seeds: int) -> void:
	var failures := 0
	for i in seeds:
		var seed_value := 1000 + i * 7919
		var sig_a := _generate_signature(seed_value)
		if sig_a == "":
			failures += 1
			continue
		var sig_b := _generate_signature(seed_value)
		if sig_a != sig_b:
			_fail("seed %d is non-deterministic" % seed_value)
	_check(failures == 0, "%d/%d seeds failed generation validity" % [failures, seeds])
	print("generator soak: %d seeds" % seeds)

func _generate_signature(seed_value: int) -> String:
	GameState.start_new_run(seed_value, false)
	var generator := FloorGenerator.new()
	get_tree().root.add_child(generator)
	var result := generator.generate(GameState.floor_index)
	var sig := ""
	var grid: FacilityGrid = result.get("grid")
	if grid == null or result.get("spawn_position") == null:
		_fail("seed %d produced no grid" % seed_value)
	else:
		var walkable := 0
		for c in grid.cells:
			if c != FacilityGrid.CellType.SOLID:
				walkable += 1
		_check(walkable > 120, "seed %d: suspiciously small floor (%d cells)" % [seed_value, walkable])
		sig = "%s|%d|%d|%d" % [str(result.spawn_position), walkable, grid.doors.size(), generator.rooms.size()]
	AudioManager.stop_all_ambience()
	generator.free()
	GameState.grid = null
	GameState.run_active = false
	return sig

func _check_save_roundtrip() -> void:
	var inst := ItemInstance.new(&"bandage", 3)
	inst.condition = 55.0
	var data := inst.serialize()
	var back := ItemInstance.deserialize(data)
	_check(back.def_id == &"bandage" and back.count == 3 and is_equal_approx(back.condition, 55.0),
		"ItemInstance round-trip failed")
	var report := GameUI.render_document(DocumentDB.get_doc(&"doc_incident_104_11"), 0)
	_check(report.contains("[bgcolor="), "redaction markup absent at clearance 0")
	var full := GameUI.render_document(DocumentDB.get_doc(&"doc_incident_104_11"), 5)
	_check(not full.contains("[bgcolor="), "redaction markup present at clearance 5")
	print("serialization round-trip checked")

# ------------------------------------------------------------ util

func _walk(dir_path: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		var full := dir_path + "/" + fname
		if dir.current_is_dir():
			if not fname.begins_with("."):
				out.append_array(_walk(full, ext))
		elif fname.ends_with(ext):
			out.append(full)
		fname = dir.get_next()
	return out
