## Hybrid floor generation (PLAN §6.3): hand-authored room definitions,
## procedural assembly, per-floor identity (PLAN §6.2). Mandatory rooms
## place first, corridors connect via a spanning tree PLUS extra loop edges,
## then validity is asserted — spawn -> card -> keycard office -> exit must
## be provably completable at the right clearances — and the whole thing
## reseeds on failure.
class_name FloorGenerator
extends Node

const ROOMS_DIR := "res://data/room_prefabs"
const MAX_ATTEMPTS := 30
## Specials every floor must have; other specials (SCP chambers) are
## included when a room def carrying them lists this floor.
const CORE_SPECIALS := ["spawn", "stairwell", "keycard_office"]

var grid: FacilityGrid
var rooms: Array[Dictionary] = [] # {def: RoomDef, rect: Rect2i, id: int}
var plan: Dictionary = {}         # generator decisions the builder realizes

var _floor_def: FloorDef

func generate(floor_index: int) -> Dictionary:
	_floor_def = load("res://data/floors/floor_%d.tres" % floor_index) as FloorDef
	if _floor_def == null:
		push_error("FloorGenerator: no FloorDef for floor %d" % floor_index)
		return {}
	var room_defs := _load_room_defs(floor_index)
	for attempt in MAX_ATTEMPTS:
		var rng := RNG.stream(StringName("layout_floor_%d_a%d" % [floor_index, attempt]))
		if _attempt(_floor_def, room_defs, rng):
			break
		grid = null
	if grid == null:
		push_error("FloorGenerator: all %d attempts failed — using fallback layout" % MAX_ATTEMPTS)
		_fallback_layout(_floor_def, room_defs)
	GameState.grid = grid
	LightProbe.ambient_floor = _floor_def.ambient_light

	var builder := RoomBuilder.new()
	add_child(builder)
	var spawn_position: Vector3 = builder.build(grid, rooms, _floor_def, plan)

	_spawn_scps(_floor_def)
	_spawn_site_corpses(floor_index, builder)
	AudioManager.start_ambience(_floor_def.ambience_sound, -16.0)
	_start_pa(_floor_def)
	EventBus.floor_generated.emit(floor_index)
	return {"spawn_position": spawn_position, "grid": grid}

func _load_room_defs(floor_index: int) -> Array[RoomDef]:
	var out: Array[RoomDef] = []
	var dir := DirAccess.open(ROOMS_DIR)
	if dir == null:
		push_error("FloorGenerator: cannot open " + ROOMS_DIR)
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var base := fname.trim_suffix(".remap")
			if base.ends_with(".tres") or base.ends_with(".res"):
				var def := load(ROOMS_DIR + "/" + base) as RoomDef
				if def != null and def.floors.has(floor_index):
					out.append(def)
		fname = dir.get_next()
	out.sort_custom(func(a: RoomDef, b: RoomDef) -> bool: return str(a.id) < str(b.id))
	return out

# ---------------------------------------------------------------- attempt

func _attempt(floor_def: FloorDef, room_defs: Array[RoomDef], rng: RandomNumberGenerator) -> bool:
	grid = FacilityGrid.new(floor_def.grid_width, floor_def.grid_height)
	rooms = []
	plan = {"pickups": [], "corpses": [], "markers": {}, "doors": []}

	# 1) Mandatory rooms first (PLAN §6.3.b): exit FIRST, far from spawn.
	var special_defs := {}
	for def in room_defs:
		if def.special != "":
			special_defs[def.special] = def
	for s in CORE_SPECIALS:
		if not special_defs.has(s):
			push_error("FloorGenerator: floor %d missing special room def '%s'" % [floor_def.floor_index, s])
			return false

	var w := floor_def.grid_width
	var h := floor_def.grid_height
	if not _place_room(special_defs["spawn"], Rect2i(2, h / 2 - 5, 6, 10), rng):
		return false
	var spawn_center := _room_center(rooms[0])
	if not _place_far(special_defs["stairwell"], spawn_center, float(w) * 0.62, rng):
		return false
	if not _place_far(special_defs["keycard_office"], spawn_center, float(w) * 0.3, rng):
		return false
	for s in special_defs:
		if not CORE_SPECIALS.has(s):
			if not _place_far(special_defs[s], spawn_center, float(w) * 0.3, rng):
				return false

	# 2) Weighted fill (PLAN §6.3.e).
	var fillable := room_defs.filter(func(d: RoomDef) -> bool: return d.special == "")
	var placed_counts := {}
	var guard := 0
	while rooms.size() < floor_def.target_rooms and guard < 500:
		guard += 1
		var def := _weighted_pick(fillable, placed_counts, rng)
		if def == null:
			break
		if _place_anywhere(def, rng):
			placed_counts[def.id] = int(placed_counts.get(def.id, 0)) + 1

	if rooms.size() < special_defs.size() + 4:
		return false

	# 3) Corridors: spanning tree + loops (PLAN §6.3.f).
	if not _weave_corridors(floor_def, rng):
		return false
	grid.build_graphs()

	# 4) Guaranteed keycard chain scaled to this floor's exit clearance
	# (PLAN §6.4: never exactly one way — SCP-914 upgrades and corpse loot
	# provide the alternates).
	if not _plan_keycards(rng):
		return false

	# 5) Validity assertions (PLAN §6.3 step 3).
	return _validate()

func _room_center(room: Dictionary) -> Vector2i:
	var r: Rect2i = room.rect
	return Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)

func _place_room(def: RoomDef, search_area: Rect2i, rng: RandomNumberGenerator) -> bool:
	for _try in 80:
		var x := rng.randi_range(search_area.position.x, maxi(search_area.position.x, search_area.end.x - def.size_w))
		var y := rng.randi_range(search_area.position.y, maxi(search_area.position.y, search_area.end.y - def.size_h))
		if _try_put(def, Vector2i(x, y)):
			return true
	return false

func _place_far(def: RoomDef, from: Vector2i, min_dist: float, rng: RandomNumberGenerator) -> bool:
	for _try in 120:
		var x := rng.randi_range(2, grid.width - def.size_w - 2)
		var y := rng.randi_range(2, grid.height - def.size_h - 2)
		if Vector2(from).distance_to(Vector2(x, y)) < min_dist:
			continue
		if _try_put(def, Vector2i(x, y)):
			return true
	return false

func _place_anywhere(def: RoomDef, rng: RandomNumberGenerator) -> bool:
	for _try in 60:
		var x := rng.randi_range(2, grid.width - def.size_w - 2)
		var y := rng.randi_range(2, grid.height - def.size_h - 2)
		if _try_put(def, Vector2i(x, y)):
			return true
	return false

func _try_put(def: RoomDef, at: Vector2i) -> bool:
	var rect := Rect2i(at, Vector2i(def.size_w, def.size_h))
	if rect.position.x < 1 or rect.position.y < 1:
		return false
	if rect.end.x > grid.width - 1 or rect.end.y > grid.height - 1:
		return false
	# Require a 2-cell SOLID margin so corridors can weave between rooms.
	for y in range(rect.position.y - 2, rect.end.y + 2):
		for x in range(rect.position.x - 2, rect.end.x + 2):
			var c := Vector2i(x, y)
			if grid.in_bounds(c) and grid.cell_type(c) != FacilityGrid.CellType.SOLID:
				return false
	var room_id := rooms.size()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			grid.set_cell(Vector2i(x, y), FacilityGrid.CellType.ROOM, room_id)
	rooms.append({"def": def, "rect": rect, "id": room_id})
	return true

func _weighted_pick(defs: Array, counts: Dictionary, rng: RandomNumberGenerator) -> RoomDef:
	var total := 0.0
	var eligible: Array = []
	for def: RoomDef in defs:
		if int(counts.get(def.id, 0)) < def.max_instances:
			eligible.append(def)
			total += def.weight
	if eligible.is_empty():
		return null
	var pick := rng.randf() * total
	for def: RoomDef in eligible:
		pick -= def.weight
		if pick <= 0.0:
			return def
	return eligible[-1]

# ---------------------------------------------------------------- corridors

func _weave_corridors(floor_def: FloorDef, rng: RandomNumberGenerator) -> bool:
	var n := rooms.size()
	var edges: Array = []
	for i in n:
		for j in range(i + 1, n):
			var d := Vector2(_room_center(rooms[i])).distance_to(Vector2(_room_center(rooms[j])))
			edges.append({"a": i, "b": j, "d": d})
	edges.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.d < y.d)

	var parent := PackedInt32Array()
	parent.resize(n)
	for i in n:
		parent[i] = i
	var chosen: Array = []
	for e in edges:
		if _find(parent, e.a) != _find(parent, e.b):
			_union(parent, e.a, e.b)
			chosen.append(e)
	var extra := int(ceil(chosen.size() * floor_def.extra_link_fraction))
	var shortish := edges.filter(func(e: Dictionary) -> bool: return not chosen.has(e))
	for _i in extra:
		if shortish.is_empty():
			break
		var pick_index := mini(rng.randi_range(0, mini(14, shortish.size() - 1)), shortish.size() - 1)
		chosen.append(shortish.pop_at(pick_index))

	for e in chosen:
		if not _carve_link(rooms[e.a], rooms[e.b], rng):
			return false
	return true

func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i

func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	parent[_find(parent, a)] = _find(parent, b)

func _carve_link(room_a: Dictionary, room_b: Dictionary, rng: RandomNumberGenerator) -> bool:
	var porch_a := _pick_porch(room_a, _room_center(room_b), rng)
	var porch_b := _pick_porch(room_b, _room_center(room_a), rng)
	if porch_a.is_empty() or porch_b.is_empty():
		return false
	var path := _corridor_path(porch_a.outside, porch_b.outside)
	if path.is_empty():
		return false
	for c in path:
		if grid.cell_type(c) == FacilityGrid.CellType.SOLID:
			grid.set_cell(c, FacilityGrid.CellType.CORRIDOR)
	_register_door(porch_a, room_a)
	_register_door(porch_b, room_b)
	return true

func _pick_porch(room: Dictionary, toward: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var rect: Rect2i = room.rect
	var candidates: Array = []
	for x in range(rect.position.x, rect.end.x):
		candidates.append({"inside": Vector2i(x, rect.position.y), "outside": Vector2i(x, rect.position.y - 1)})
		candidates.append({"inside": Vector2i(x, rect.end.y - 1), "outside": Vector2i(x, rect.end.y)})
	for y in range(rect.position.y, rect.end.y):
		candidates.append({"inside": Vector2i(rect.position.x, y), "outside": Vector2i(rect.position.x - 1, y)})
		candidates.append({"inside": Vector2i(rect.end.x - 1, y), "outside": Vector2i(rect.end.x, y)})
	var valid := candidates.filter(func(c: Dictionary) -> bool:
		return grid.in_bounds(c.outside) and grid.cell_type(c.outside) != FacilityGrid.CellType.ROOM)
	if valid.is_empty():
		return {}
	for c in valid:
		if grid.has_door(c.inside, c.outside):
			return c
	valid.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		return Vector2(p.outside).distance_to(Vector2(toward)) < Vector2(q.outside).distance_to(Vector2(toward)))
	var top := mini(3, valid.size())
	return valid[rng.randi_range(0, top - 1)]

func _register_door(porch: Dictionary, room: Dictionary) -> void:
	if grid.has_door(porch.inside, porch.outside):
		return
	var def: RoomDef = room.def
	var blast: bool = def.special == "stairwell"
	# Per-floor clearance for the progression rooms: the stairwell takes the
	# floor's exit clearance; the keycard office sits one level below it.
	var clearance := def.door_clearance
	if def.special == "stairwell":
		clearance = _floor_def.exit_clearance
	elif def.special == "keycard_office":
		clearance = maxi(_floor_def.exit_clearance - 1, 0)
	grid.add_door(porch.inside, porch.outside, "", blast)
	plan.doors.append({
		"a": porch.inside, "b": porch.outside,
		"clearance": clearance, "blast": blast,
		"powered_down_chance": def.powered_down_chance, "room_id": room.id,
	})

func _corridor_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, grid.width, grid.height)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	for y in grid.height:
		for x in grid.width:
			var c := Vector2i(x, y)
			var t := grid.cell_type(c)
			if t == FacilityGrid.CellType.ROOM:
				astar.set_point_solid(c, true)
			elif t == FacilityGrid.CellType.CORRIDOR:
				astar.set_point_weight_scale(c, 1.0)
			else:
				astar.set_point_weight_scale(c, 3.0)
	for x in grid.width:
		astar.set_point_solid(Vector2i(x, 0), true)
		astar.set_point_solid(Vector2i(x, grid.height - 1), true)
	for y in grid.height:
		astar.set_point_solid(Vector2i(0, y), true)
		astar.set_point_solid(Vector2i(grid.width - 1, y), true)
	if astar.is_point_solid(from) or astar.is_point_solid(to):
		return []
	var pts := astar.get_id_path(from, to)
	var out: Array[Vector2i] = []
	for p in pts:
		out.append(p)
	return out

# ---------------------------------------------------------------- keycards

func _plan_keycards(rng: RandomNumberGenerator) -> bool:
	var exit_level := _floor_def.exit_clearance
	var office := _room_by_special("keycard_office")
	if office.is_empty():
		return false
	# Card A (exit-1): lies in the open, reachable at the floor's entry
	# clearance. Level 0 floors skip it — the office is already open.
	if exit_level >= 2:
		var open_rooms := rooms.filter(func(r: Dictionary) -> bool:
			var d: RoomDef = r.def
			return d.special == "" and d.door_clearance == 0)
		if open_rooms.is_empty():
			return false
		open_rooms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _dist_to_spawn(a) < _dist_to_spawn(b))
		var host: Dictionary = open_rooms[mini(rng.randi_range(1, 3), open_rooms.size() - 1)]
		plan.pickups.append({"cell": _random_room_cell(host, rng), "item": "keycard_l%d" % (exit_level - 1), "count": 1})
	# Card B (exit level): inside the keycard office.
	plan.pickups.append({"cell": _random_room_cell(office, rng), "item": "keycard_l%d" % exit_level, "count": 1})
	return true

func _dist_to_spawn(room: Dictionary) -> float:
	return Vector2(_room_center(rooms[0])).distance_to(Vector2(_room_center(room)))

func _room_by_special(s: String) -> Dictionary:
	for r in rooms:
		if (r.def as RoomDef).special == s:
			return r
	return {}

func _random_room_cell(room: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var rect: Rect2i = room.rect
	return Vector2i(
		rng.randi_range(rect.position.x, rect.end.x - 1),
		rng.randi_range(rect.position.y, rect.end.y - 1))

# ---------------------------------------------------------------- validity

func _validate() -> bool:
	var spawn_cell := _room_center(rooms[0])
	for room in rooms:
		if grid.find_path_open(spawn_cell, _room_center(room)).is_empty():
			return false
	# Clearance-gated progression, generalized per floor:
	# entry clearance -> card A (exit-1) -> card B (exit) -> stairwell.
	var exit_level := _floor_def.exit_clearance
	var exit_cell := _room_center(_room_by_special("stairwell"))
	var cursor := spawn_cell
	var have := 0
	if exit_level >= 2:
		var card_a_cell: Vector2i = plan.pickups[0].cell
		if not _reachable_with_clearance(cursor, card_a_cell, have):
			return false
		cursor = card_a_cell
		have = exit_level - 1
	var card_b_cell: Vector2i = plan.pickups[-1].cell
	if not _reachable_with_clearance(cursor, card_b_cell, have):
		return false
	if not _reachable_with_clearance(card_b_cell, exit_cell, exit_level):
		return false
	var doors_by_room := {}
	for d in plan.get("doors", []):
		doors_by_room[d.room_id] = true
	for room in rooms:
		if not doors_by_room.has(room.id):
			return false
	return true

func _reachable_with_clearance(from: Vector2i, to: Vector2i, clearance: int) -> bool:
	var door_clearances := {}
	for d in plan.get("doors", []):
		var key := "%s|%s" % [d.a, d.b]
		door_clearances[key] = d.clearance
		door_clearances["%s|%s" % [d.b, d.a]] = d.clearance
	var queue: Array[Vector2i] = [from]
	var seen := {from: true}
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			return true
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + offset
			if seen.has(n) or not grid.is_walkable(n):
				continue
			if not grid.edge_passable(c, n):
				continue
			var key := "%s|%s" % [c, n]
			if door_clearances.has(key) and int(door_clearances[key]) > clearance:
				continue
			seen[n] = true
			queue.append(n)
	return false

# ---------------------------------------------------------------- fallback

## Known-good static layout with whatever specials this floor carries.
func _fallback_layout(floor_def: FloorDef, room_defs: Array[RoomDef]) -> void:
	grid = FacilityGrid.new(floor_def.grid_width, floor_def.grid_height)
	rooms = []
	plan = {"pickups": [], "corpses": [], "markers": {}, "doors": []}
	var mid := floor_def.grid_height / 2
	for x in range(3, floor_def.grid_width - 3):
		grid.set_cell(Vector2i(x, mid), FacilityGrid.CellType.CORRIDOR)
	var special_defs := {}
	var filler: RoomDef = null
	for def in room_defs:
		if def.special != "":
			special_defs[def.special] = def
		elif filler == null:
			filler = def
	var order: Array = ["spawn"]
	for s in special_defs:
		if not CORE_SPECIALS.has(s):
			order.append(s)
	if filler != null:
		order.append("")
	order.append("keycard_office")
	order.append("stairwell")
	var x_cursor := 4
	for s in order:
		var def: RoomDef = special_defs.get(s, filler)
		if def == null:
			continue
		var at := Vector2i(x_cursor, mid - def.size_h - 1)
		if not _try_put(def, at):
			x_cursor += 2
			continue
		var room: Dictionary = rooms[-1]
		var inside := Vector2i(at.x + def.size_w / 2, at.y + def.size_h - 1)
		var outside := Vector2i(inside.x, inside.y + 1)
		for y in range(outside.y, mid + 1):
			if grid.cell_type(Vector2i(inside.x, y)) == FacilityGrid.CellType.SOLID:
				grid.set_cell(Vector2i(inside.x, y), FacilityGrid.CellType.CORRIDOR)
		grid.add_door(inside, outside, "", def.special == "stairwell")
		var clearance := def.door_clearance
		if def.special == "stairwell":
			clearance = floor_def.exit_clearance
		elif def.special == "keycard_office":
			clearance = maxi(floor_def.exit_clearance - 1, 0)
		plan.doors.append({
			"a": inside, "b": outside, "clearance": clearance,
			"blast": def.special == "stairwell", "powered_down_chance": 0.0, "room_id": room.id,
		})
		x_cursor += def.size_w + 4
	grid.build_graphs()
	var rng := RNG.stream(&"fallback")
	_plan_keycards(rng)

# ---------------------------------------------------------------- spawning

func _spawn_scps(floor_def: FloorDef) -> void:
	for scp_name in floor_def.scp_spawns:
		var script_path := "res://src/scps/%s.gd" % scp_name
		if not ResourceLoader.exists(script_path):
			push_error("FloorGenerator: missing SCP script " + script_path)
			continue
		var scp_script: GDScript = load(script_path)
		var scp: Node3D = scp_script.new()
		if "persist_id" in scp:
			scp.persist_id = "%s_%d" % [scp_name, get_child_count()]
		add_child(scp)
		var start_cell := _scp_start_cell(scp_name)
		scp.global_position = grid.cell_to_world(start_cell) + Vector3.UP * 0.02
		if scp.has_method("set_home_cell"):
			scp.set_home_cell(start_cell)

func _scp_start_cell(scp_name: StringName) -> Vector2i:
	match scp_name:
		&"scp_173":
			var chamber := _room_by_special("scp_173_chamber")
			if not chamber.is_empty():
				return _room_center(chamber)
		&"scp_049":
			# The Doctor starts far from the arrival point, at his work.
			var far := _room_by_special("keycard_office")
			if not far.is_empty():
				return _room_center(far) + Vector2i(1, 0)
	return grid.random_walkable_cell(RNG.stream(StringName("spawn_" + scp_name)))

func _spawn_site_corpses(floor_index: int, builder: RoomBuilder) -> void:
	# Previous runs' bodies, wearing everything they died in (PLAN §16.3).
	var has_049 := _floor_def.scp_spawns.has(&"scp_049")
	var records := FacilityState.corpses_on_floor(floor_index)
	for i in records.size():
		var rec: Dictionary = records[i]
		var cell_arr: Array = rec.get("cell", [0, 0])
		var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
		if not grid.is_walkable(cell):
			cell = grid.random_walkable_cell(RNG.stream(&"corpse_relocate"))
		var corpse := Corpse.create_player_remains(rec, i)
		builder.add_child(corpse)
		corpse.global_position = grid.cell_to_world(cell)
		# PLAN §20.1: on the Doctor's floor, your predecessor did not stay
		# down. It stands over its own body, wearing what it can't use.
		if has_049 and bool(rec.get("pestilent", false)):
			var risen := SCP049_2.new()
			risen.anchor_cell = cell
			risen.risen_designation = rec.get("designation", "")
			add_child(risen)
			risen.global_position = grid.cell_to_world(cell) + Vector3(1.2, 0.02, 0.8)

func _start_pa(floor_def: FloorDef) -> void:
	if floor_def.pa_lines.is_empty():
		return
	var timer := Timer.new()
	timer.wait_time = 150.0
	timer.autostart = true
	add_child(timer)
	var line_index := [0]
	timer.timeout.connect(func() -> void:
		var rng := RNG.stream(&"pa")
		if rng.randf() < 0.4:
			return # silence is a tool (PLAN §14.2)
		AudioManager.play_ui(&"pa_chime", -10.0)
		EventBus.pa_announcement.emit(floor_def.pa_lines[line_index[0] % floor_def.pa_lines.size()])
		line_index[0] += 1)
