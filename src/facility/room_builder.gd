## Realizes a generated floor as world geometry: floors, walls, ceilings,
## doors, lights, environment, and per-room dressing. Everything is built
## from primitive meshes with shared materials (docs/ARCHITECTURE.md — no
## binary assets); lighting and fog do the aesthetic heavy lifting
## (PLAN §13.2: "lighting does 70% of the work").
class_name RoomBuilder
extends Node3D

const WALL_H := 3.2
const WALL_T := 0.24

var _grid: FacilityGrid
var _floor_def: FloorDef
var _rooms: Array[Dictionary]
var _plan: Dictionary
var _rng: RandomNumberGenerator
var _structure: StaticBody3D
var _mat_cache: Dictionary = {}
var _doc_pool: Array = []
var _container_counter := 0
var _pickup_counter := 0
var _spawn_position := Vector3.ZERO
var _shadow_budget := 6 # max shadow-casting fixtures (PLAN §13.2)

func build(grid: FacilityGrid, rooms: Array[Dictionary], floor_def: FloorDef, plan: Dictionary) -> Vector3:
	_grid = grid
	_rooms = rooms
	_floor_def = floor_def
	_plan = plan
	_rng = RNG.stream(StringName("dressing_floor_%d" % floor_def.floor_index))
	_doc_pool = DocumentDB.docs_for_floor(floor_def.floor_index)
	# Deterministic shuffle of the lore pool.
	for i in range(_doc_pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = _doc_pool[i]
		_doc_pool[i] = _doc_pool[j]
		_doc_pool[j] = tmp

	_structure = StaticBody3D.new()
	_structure.name = "Structure"
	_structure.collision_layer = 1
	_structure.collision_mask = 0
	_structure.set_meta("footstep_mat", "concrete")
	add_child(_structure)

	_build_environment()
	_build_shell()
	_build_doors()
	for room in _rooms:
		_dress_room(room)
	_place_planned_pickups()
	_corridor_lights()
	_wayfinding()
	return _spawn_position

# ---------------------------------------------------------------- shell

func _build_shell() -> void:
	var cell := FacilityGrid.CELL_SIZE
	for y in _grid.height:
		for x in _grid.width:
			var c := Vector2i(x, y)
			if not _grid.is_walkable(c):
				continue
			var base := _grid.cell_to_world(c)
			var is_room := _grid.cell_type(c) == FacilityGrid.CellType.ROOM
			var tint := _floor_def.wall_tint
			var floor_mat := _mat((Color(0.62, 0.63, 0.6) if is_room else Color(0.5, 0.51, 0.5)) * tint, 0.7, 0.05)
			_box(_structure, base + Vector3(0, -0.1, 0), Vector3(cell, 0.2, cell), floor_mat)
			# No ceiling mesh: the isometric camera looks down into the
			# rooms (PZ hides roofs). Skipping them is also a large
			# draw-call saving on a 34x34 floor.
			# Walls: neighbor solid, or walkable but not passable (and no door
			# — door edges get their frame from the Door node itself).
			for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var n: Vector2i = c + offset
				var needs_wall := false
				if not _grid.is_walkable(n):
					needs_wall = true
				elif _grid.has_door(c, n):
					needs_wall = false # door builds the frame
				elif not _grid.edge_passable(c, n):
					# Build interior walls once per edge (from the lower cell).
					needs_wall = offset == Vector2i(1, 0) or offset == Vector2i(0, 1)
				if not needs_wall:
					continue
				var wall_center := base + Vector3(offset.x * cell * 0.5, WALL_H * 0.5, offset.y * cell * 0.5)
				var wall_size := Vector3(WALL_T, WALL_H, cell) if offset.x != 0 else Vector3(cell, WALL_H, WALL_T)
				var wall_color := (Color(0.68, 0.69, 0.7) if is_room else Color(0.58, 0.6, 0.62)) * tint
				_box(_structure, wall_center, wall_size, _mat(wall_color, 0.85, 0.0))

func _build_doors() -> void:
	for d in _plan.get("doors", []):
		var door := Door.new()
		var initial := Door.DoorState.UNLOCKED
		var clearance: int = d.clearance
		if clearance > 0:
			initial = Door.DoorState.LOCKED
		elif float(d.powered_down_chance) > 0.0 and _rng.randf() < float(d.powered_down_chance):
			initial = Door.DoorState.POWERED_DOWN
		door.setup(_grid, d.a, d.b, clearance, d.blast, initial)
		add_child(door)

# ---------------------------------------------------------------- rooms

func _dress_room(room: Dictionary) -> void:
	var def: RoomDef = room.def
	var rect: Rect2i = room.rect
	_room_lights(room)
	match def.special:
		"spawn":
			_dress_spawn(room)
			return
		"stairwell":
			_dress_stairwell(room)
			return
		"scp_173_chamber":
			_dress_173_chamber(room)
			return
		"scp_914":
			_dress_914_room(room)
			return
	match def.style:
		"office", "keycard_office":
			_dress_office(room)
		"storage":
			_dress_storage(room)
		"break_room":
			_dress_break_room(room)
		"containment_cell":
			_dress_containment(room)
		"lab":
			_dress_lab(room)
		"checkpoint":
			_dress_checkpoint(room)
		"lobby":
			_dress_lobby(room)
		"decon":
			_dress_decon(room)
		"dorm":
			_dress_dorm(room)
		"server":
			_dress_server(room)
		"autopsy":
			_dress_autopsy(room)
		"cryo":
			_dress_cryo(room)
		_:
			pass
	# Shared dressing: containers, documents, corpses, scatter.
	var n_containers := _rng.randi_range(def.containers_min, def.containers_max)
	for _i in n_containers:
		_container_at(_room_spot(rect), _container_kind_for(def.style), def.loot_table)
	var n_docs := _rng.randi_range(def.documents_min, def.documents_max)
	for _i in n_docs:
		_document_at(_room_spot(rect))
	if _rng.randf() < def.corpse_chance:
		_corpse_at(_room_spot(rect), &"corpse_staff", Color(0.7, 0.7, 0.72))
	_name_plate(room)

func _room_lights(room: Dictionary) -> void:
	var def: RoomDef = room.def
	var rect: Rect2i = room.rect
	# One fixture per ~3x3 cells, centered on sub-areas.
	var nx := maxi(1, rect.size.x / 3)
	var ny := maxi(1, rect.size.y / 3)
	for iy in ny:
		for ix in nx:
			var cx := rect.position.x + (ix * rect.size.x) / nx + rect.size.x / (nx * 2)
			var cy := rect.position.y + (iy * rect.size.y) / ny + rect.size.y / (ny * 2)
			var pos := _grid.cell_to_world(Vector2i(cx, cy)) + Vector3(0, WALL_H - 0.15, 0)
			_light_fixture(pos, def.light_color, _rng.randf() < def.broken_light_chance)

func _light_fixture(pos: Vector3, color: Color, broken: bool) -> void:
	var dead := broken and _rng.randf() < 0.4 # some broken lights are just dead
	var panel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 0.08, 0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.86, 0.88)
	if not dead:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.6
	mesh.material = mat
	panel.mesh = mesh
	add_child(panel)
	panel.global_position = pos
	if dead:
		return
	var light: OmniLight3D
	if broken:
		var flicker := LightFlicker.new()
		flicker.flicker_seed = _rng.randi()
		light = flicker
	else:
		light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.1
	light.omni_range = 7.5
	light.shadow_enabled = _shadow_budget > 0
	if light.shadow_enabled:
		_shadow_budget -= 1
	light.add_to_group(&"probe_light")
	add_child(light)
	light.global_position = pos + Vector3.DOWN * 0.35

func _corridor_lights() -> void:
	for y in _grid.height:
		for x in _grid.width:
			var c := Vector2i(x, y)
			if _grid.cell_type(c) != FacilityGrid.CellType.CORRIDOR:
				continue
			if (x + y) % _floor_def.corridor_light_spacing != 0:
				continue
			var pos := _grid.cell_to_world(c) + Vector3(0, WALL_H - 0.15, 0)
			_light_fixture(pos, _floor_def.light_color,
				_rng.randf() < _floor_def.corridor_broken_light_chance)

## Exit signage at corridor cells: follow the nav path toward the stairwell.
func _wayfinding() -> void:
	var exit_room := {}
	for r in _rooms:
		if (r.def as RoomDef).special == "stairwell":
			exit_room = r
	if exit_room.is_empty():
		return
	var exit_cell: Vector2i = Vector2i(
		(exit_room.rect as Rect2i).position.x + (exit_room.rect as Rect2i).size.x / 2,
		(exit_room.rect as Rect2i).position.y + (exit_room.rect as Rect2i).size.y / 2)
	var placed := 0
	for y in _grid.height:
		for x in _grid.width:
			if placed >= 10:
				return
			var c := Vector2i(x, y)
			if _grid.cell_type(c) != FacilityGrid.CellType.CORRIDOR or (x * 7 + y * 13) % 11 != 0:
				continue
			var path := _grid.find_path_open(c, exit_cell)
			if path.size() < 3:
				continue
			var toward := _grid.cell_to_world(path[1]) - _grid.cell_to_world(c)
			var sign_label := Label3D.new()
			sign_label.text = "◄ S-3 STAIRWELL"
			sign_label.font_size = 26
			sign_label.modulate = Color(0.4, 0.9, 0.5)
			add_child(sign_label)
			sign_label.global_position = _grid.cell_to_world(c) + Vector3(0, 2.6, 0)
			sign_label.rotation.y = atan2(toward.x, toward.z) + PI
			placed += 1

# ---------------------------------------------------------------- specials

func _dress_spawn(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var center := _rect_center_world(rect)
	_spawn_position = center + Vector3(0, 0.1, 0)
	# Your open cell: a bunk, a tray, the paperwork that put you here.
	_box(_structure, center + Vector3(-1.4, 0.3, -1.2), Vector3(2.0, 0.3, 0.9), _mat(Color(0.35, 0.37, 0.4), 0.9, 0.0))
	var sign_label := Label3D.new()
	sign_label.text = "D-CLASS PROCESSING\nBLOCK 3-C"
	sign_label.font_size = 40
	sign_label.modulate = Color(0.9, 0.6, 0.25)
	add_child(sign_label)
	sign_label.global_position = center + Vector3(0, 2.5, -1.8)
	if _floor_def.floor_index != GameState.DEFAULT_FLOOR:
		_name_plate(room)
		return
	# Personal effects locker: a guaranteed starter kit, searchable.
	var effects := WorldContainer.new()
	effects.configure_fixed("f%d_cont_spawn_effects" % _floor_def.floor_index, "personal effects locker", [
		ItemInstance.new(&"flashlight").serialize(),
		ItemInstance.new(&"battery").serialize(),
		ItemInstance.new(&"ripped_sheet", 2).serialize(),
		ItemInstance.new(&"snack_bar").serialize(),
	], 1.5)
	_container_visual(effects, "locker")
	add_child(effects)
	effects.global_position = _room_spot(rect)
	# The orientation document is guaranteed here.
	if _doc_pool.has(&"doc_orientation"):
		_doc_pool.erase(&"doc_orientation")
		_place_document(_room_spot(rect), &"doc_orientation")
	_name_plate(room)

func _dress_stairwell(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var exit := StairwellExit.new()
	exit.floor_def = _floor_def
	add_child(exit)
	exit.global_position = _rect_center_world(rect)
	# Emergency lighting: green, reliable — the one place that feels safe.
	_light_fixture(_rect_center_world(rect) + Vector3(0, WALL_H - 0.15, 0), Color(0.5, 0.95, 0.6), false)

func _dress_173_chamber(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var center := _rect_center_world(rect)
	# Breached containment: shattered observation window, ochre residue.
	_box(_structure, center + Vector3(0, 1.9, -rect.size.y * FacilityGrid.CELL_SIZE * 0.5 + 0.5),
		Vector3(3.0, 1.2, 0.08), _mat(Color(0.75, 0.85, 0.9, 0.35), 0.1, 0.0, true))
	for _i in 8:
		var shard := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.25, 0.18, 0.03)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8, 0.88, 0.92, 0.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
		shard.mesh = mesh
		add_child(shard)
		shard.global_position = center + Vector3(_rng.randf_range(-2, 2), 0.03, _rng.randf_range(-2, 0))
		shard.rotation.y = _rng.randf_range(0.0, TAU)
	for _i in 5:
		_residue_decal(center + Vector3(_rng.randf_range(-3, 3), 0.011, _rng.randf_range(-3, 3)))
	var warn := Label3D.new()
	warn.text = "SCP-173 — EUCLID\nMAINTAIN DIRECT VISUAL CONTACT AT ALL TIMES\nMINIMUM THREE (3) PERSONNEL DURING ENTRY"
	warn.font_size = 30
	warn.modulate = Color(0.9, 0.75, 0.2)
	add_child(warn)
	warn.global_position = center + Vector3(0, 2.4, rect.size.y * FacilityGrid.CELL_SIZE * 0.5 - 0.5)
	warn.rotation.y = PI
	_corpse_at(center + Vector3(1.2, 0, 1.4), &"corpse_guard", Color(0.45, 0.48, 0.52))
	_name_plate(room)

func _dress_914_room(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var machine := SCP914.new()
	add_child(machine)
	machine.global_position = _rect_center_world(rect)
	if _doc_pool.has(&"doc_914_protocol"):
		_doc_pool.erase(&"doc_914_protocol")
		_place_document(_room_spot(rect), &"doc_914_protocol")
	_name_plate(room)

# ---------------------------------------------------------------- styles

func _dress_office(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var n_desks := maxi(1, (rect.size.x * rect.size.y) / 6)
	for _i in n_desks:
		var pos := _room_spot(rect)
		_box(_structure, pos + Vector3(0, 0.72, 0), Vector3(1.5, 0.07, 0.75), _mat(Color(0.5, 0.42, 0.32), 0.7, 0.0))
		_box(_structure, pos + Vector3(-0.65, 0.36, 0), Vector3(0.08, 0.72, 0.7), _mat(Color(0.3, 0.3, 0.32), 0.6, 0.3))
		_box(_structure, pos + Vector3(0.65, 0.36, 0), Vector3(0.08, 0.72, 0.7), _mat(Color(0.3, 0.3, 0.32), 0.6, 0.3))
		if _rng.randf() < 0.55: # dead monitor
			_box(_structure, pos + Vector3(0.2, 1.0, -0.1), Vector3(0.5, 0.35, 0.06), _mat(Color(0.08, 0.09, 0.1), 0.3, 0.2))
		if _rng.randf() < 0.5: # overturned chair — the aftermath (PLAN §6.2)
			var chair_pos := pos + Vector3(_rng.randf_range(-0.8, 0.8), 0.25, _rng.randf_range(0.5, 1.0))
			_box(_structure, chair_pos, Vector3(0.45, 0.5, 0.45), _mat(Color(0.2, 0.2, 0.24), 0.8, 0.0))

func _dress_storage(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	for _i in maxi(2, (rect.size.x * rect.size.y) / 4):
		var pos := _room_spot(rect)
		_box(_structure, pos + Vector3(0, 1.0, 0), Vector3(0.6, 2.0, 1.6), _mat(Color(0.35, 0.42, 0.38), 0.7, 0.4))

func _dress_break_room(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var pos := _room_spot(rect)
	_box(_structure, pos + Vector3(0, 0.75, 0), Vector3(1.8, 0.08, 0.9), _mat(Color(0.7, 0.68, 0.6), 0.8, 0.0))
	# The vending machine: emissive, humming, full of ancient calories.
	var vend := WorldContainer.new()
	vend.configure("f%d_cont_%d_vend" % [_floor_def.floor_index, _container_counter], "vending machine", &"vending", 2.0)
	_container_counter += 1
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 1.9, 0.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.2, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.4, 0.9)
	mat.emission_energy_multiplier = 0.7
	mesh.material = mat
	mi.mesh = mesh
	mi.position.y = 0.95
	mi.add_to_group(&"cutaway_wall")
	vend.add_child(mi)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	shape.shape = box
	shape.position.y = 0.95
	vend.add_child(shape)
	add_child(vend)
	vend.global_position = _room_spot(rect)

func _dress_containment(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var center := _rect_center_world(rect)
	# An empty Safe-class cell: bare, drain in the floor, one heavy window.
	_box(_structure, center + Vector3(0, 0.005, 0), Vector3(0.6, 0.01, 0.6), _mat(Color(0.2, 0.2, 0.2), 0.4, 0.6))
	_box(_structure, center + Vector3(0, 1.9, rect.size.y * FacilityGrid.CELL_SIZE * 0.5 - 0.4),
		Vector3(2.2, 1.0, 0.08), _mat(Color(0.75, 0.85, 0.9, 0.4), 0.1, 0.0, true))

func _dress_lab(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	for _i in maxi(2, (rect.size.x * rect.size.y) / 5):
		var pos := _room_spot(rect)
		_box(_structure, pos + Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.8), _mat(Color(0.85, 0.87, 0.88), 0.4, 0.1))

func _dress_checkpoint(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var center := _rect_center_world(rect)
	_box(_structure, center + Vector3(0, 0.6, 0), Vector3(2.4, 1.2, 0.9), _mat(Color(0.4, 0.42, 0.46), 0.6, 0.3))
	# A security monitor still cycling empty corridors.
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 0.4, 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.08, 0.06)
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.55, 0.25)
	mat.emission_energy_multiplier = 1.1
	mesh.material = mat
	mi.mesh = mesh
	add_child(mi)
	mi.global_position = center + Vector3(0, 1.4, 0)

func _dress_lobby(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var center := _rect_center_world(rect)
	# Reception desk, turnstiles, and the site motto nobody believed.
	_box(_structure, center + Vector3(0, 0.6, -1.5), Vector3(3.2, 1.2, 0.9), _mat(Color(0.55, 0.5, 0.45), 0.6, 0.1))
	for i in 3:
		_box(_structure, center + Vector3(-2.0 + i * 2.0, 0.55, 1.5), Vector3(0.15, 1.1, 0.7), _mat(Color(0.4, 0.42, 0.46), 0.4, 0.6))
	var motto := Label3D.new()
	motto.text = "SITE-104\nSECURE · CONTAIN · PROTECT\nDEPTH IS SECURITY"
	motto.font_size = 44
	motto.modulate = Color(0.85, 0.87, 0.9)
	add_child(motto)
	motto.global_position = center + Vector3(0, 2.6, -rect.size.y * FacilityGrid.CELL_SIZE * 0.5 + 0.4)

func _dress_decon(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var center := _rect_center_world(rect)
	for i in 4:
		var head := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.06
		mesh.bottom_radius = 0.12
		mesh.height = 0.25
		mesh.material = _mat(Color(0.6, 0.62, 0.66), 0.4, 0.7)
		head.mesh = mesh
		add_child(head)
		head.global_position = center + Vector3(-2.1 + i * 1.4, WALL_H - 0.35, 0)
	# The drain. There is old blood in the drain (PLAN §6.2 Floor 1 horror).
	_box(_structure, center + Vector3(0, 0.006, 0), Vector3(0.8, 0.012, 0.8), _mat(Color(0.16, 0.1, 0.1), 0.5, 0.3))

func _dress_dorm(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	for _i in maxi(2, (rect.size.x * rect.size.y) / 4):
		var pos := _room_spot(rect)
		_box(_structure, pos + Vector3(0, 0.3, 0), Vector3(2.0, 0.3, 0.9), _mat(Color(0.35, 0.37, 0.42), 0.9, 0.0))
		if _rng.randf() < 0.4: # overturned bunk
			_box(_structure, pos + Vector3(0.4, 0.75, 0.6), Vector3(0.9, 0.9, 0.15), _mat(Color(0.3, 0.32, 0.36), 0.9, 0.0))

func _dress_server(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	for _i in maxi(3, (rect.size.x * rect.size.y) / 3):
		var pos := _room_spot(rect)
		var rack := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.7, 2.0, 0.9)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.11, 0.13)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.9, 0.3) if _rng.randf() < 0.6 else Color(0.9, 0.4, 0.1)
		mat.emission_energy_multiplier = 0.5
		mat.metallic = 0.6
		mat.roughness = 0.4
		mesh.material = mat
		rack.mesh = mesh
		rack.position.y = 1.0
		rack.add_to_group(&"cutaway_wall")
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = mesh.size
		shape.shape = box
		shape.position.y = 1.0
		body.add_child(shape)
		body.add_child(rack)
		add_child(body)
		body.global_position = pos

func _dress_autopsy(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	for _i in maxi(2, (rect.size.x * rect.size.y) / 6):
		var pos := _room_spot(rect)
		_box(_structure, pos + Vector3(0, 0.5, 0), Vector3(2.0, 0.08, 0.8), _mat(Color(0.75, 0.78, 0.8), 0.25, 0.8))
		_box(_structure, pos + Vector3(0, 0.25, 0), Vector3(0.3, 0.5, 0.3), _mat(Color(0.4, 0.42, 0.46), 0.5, 0.5))
		if _rng.randf() < 0.5:
			_box(_structure, pos + Vector3(0, 0.58, 0), Vector3(1.7, 0.08, 0.6), _mat(Color(0.85, 0.85, 0.82), 0.9, 0.0)) # sheet

func _dress_cryo(room: Dictionary) -> void:
	var rect: Rect2i = room.rect
	var center := _rect_center_world(rect)
	for _i in maxi(2, (rect.size.x * rect.size.y) / 4):
		var pos := _room_spot(rect)
		var pod := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.4
		mesh.height = 2.2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.75, 0.85, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.5, 0.7)
		mat.emission_energy_multiplier = 0.3
		mesh.material = mat
		pod.mesh = mesh
		pod.add_to_group(&"cutaway_wall")
		add_child(pod)
		pod.global_position = pos + Vector3(0, 1.1, 0)
	var frost := Label3D.new()
	frost.text = "CRYOGENIC STORAGE — MAINTAIN SEAL"
	frost.font_size = 26
	frost.modulate = Color(0.6, 0.8, 0.95)
	add_child(frost)
	frost.global_position = center + Vector3(0, 2.7, 0)

# ---------------------------------------------------------------- helpers

func _container_kind_for(style: String) -> String:
	match style:
		"office", "keycard_office":
			return "desk drawer" if _rng.randf() < 0.5 else "filing cabinet"
		"storage":
			return "supply crate"
		"lab":
			return "lab cabinet"
		"checkpoint":
			return "security locker"
		"break_room":
			return "cupboard"
	return "cabinet"

func _container_at(pos: Vector3, kind: String, table: StringName) -> void:
	var c := WorldContainer.new()
	c.configure("f%d_cont_%d" % [_floor_def.floor_index, _container_counter], kind, table, 2.0 + _rng.randf() * 1.5)
	_container_counter += 1
	_container_visual(c, kind)
	add_child(c)
	c.global_position = pos

func _container_visual(c: WorldContainer, kind: String) -> void:
	var size := Vector3(0.9, 1.0, 0.5)
	var color := Color(0.45, 0.47, 0.5)
	match kind:
		"locker", "security locker":
			size = Vector3(0.6, 1.8, 0.5)
			color = Color(0.35, 0.45, 0.4)
		"supply crate":
			size = Vector3(1.0, 0.8, 1.0)
			color = Color(0.5, 0.45, 0.3)
		"filing cabinet":
			size = Vector3(0.5, 1.4, 0.6)
			color = Color(0.52, 0.52, 0.55)
		"desk drawer":
			size = Vector3(1.2, 0.75, 0.6)
			color = Color(0.5, 0.42, 0.32)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _mat(color, 0.75, 0.2)
	mi.mesh = mesh
	mi.position.y = size.y * 0.5
	if size.y >= CUTAWAY_MIN_HEIGHT:
		mi.add_to_group(&"cutaway_wall")
	c.add_child(mi)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	c.add_child(shape)

func _document_at(pos: Vector3) -> void:
	if _doc_pool.is_empty():
		return
	var doc_id: StringName = _doc_pool.pop_front()
	_place_document(pos, doc_id)

func _place_document(pos: Vector3, doc_id: StringName) -> void:
	var pickup_id := "f%d_doc_pickup_%d" % [_floor_def.floor_index, _pickup_counter]
	_pickup_counter += 1
	if FacilityState.removed_pickups.has(pickup_id):
		return
	var p := DocumentPickup.create(pickup_id, doc_id)
	add_child(p)
	p.global_position = pos + Vector3(0, 0.76, 0) # desk height reads naturally

func _corpse_at(pos: Vector3, table: StringName, color: Color) -> void:
	var c := Corpse.create_scripted("f%d_corpse_%d" % [_floor_def.floor_index, _container_counter], table, color)
	_container_counter += 1
	add_child(c)
	c.global_position = pos

func _place_planned_pickups() -> void:
	for entry in _plan.get("pickups", []):
		var pickup_id := "f%d_plan_pickup_%d" % [_floor_def.floor_index, _pickup_counter]
		_pickup_counter += 1
		if FacilityState.removed_pickups.has(pickup_id):
			continue
		var inst := ItemInstance.new(StringName(entry.item), int(entry.get("count", 1)))
		if inst.definition() == null:
			push_error("RoomBuilder: unknown planned item " + str(entry.item))
			continue
		var p := ItemPickup.create(pickup_id, inst)
		add_child(p)
		p.global_position = _grid.cell_to_world(entry.cell) + Vector3(0, 0.78, 0)
		# A pedestal so guaranteed progression items are visible.
		_box(_structure, _grid.cell_to_world(entry.cell) + Vector3(0, 0.36, 0),
			Vector3(0.5, 0.72, 0.5), _mat(Color(0.4, 0.42, 0.45), 0.6, 0.2))

func _residue_decal(pos: Vector3) -> void:
	# SCP-173's ochre spray-paint flake trail — learn to read it (PLAN §7.3).
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.35
	mesh.bottom_radius = 0.35
	mesh.height = 0.006
	mesh.material = _mat(Color(0.62, 0.4, 0.12), 0.95, 0.0)
	mi.mesh = mesh
	add_child(mi)
	mi.global_position = pos

func _name_plate(room: Dictionary) -> void:
	var def: RoomDef = room.def
	if def.display_name == "":
		return
	var rect: Rect2i = room.rect
	var label := Label3D.new()
	label.text = def.display_name.to_upper()
	label.font_size = 24
	label.modulate = Color(0.75, 0.78, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0006
	add_child(label)
	label.global_position = _rect_center_world(rect) + Vector3(0, 2.4, 0)

func _rect_center_world(rect: Rect2i) -> Vector3:
	var a := _grid.cell_to_world(rect.position)
	var b := _grid.cell_to_world(rect.end - Vector2i.ONE)
	return (a + b) * 0.5

## A deterministic scatter point inside a room, biased off exact center.
func _room_spot(rect: Rect2i) -> Vector3:
	var cell := Vector2i(
		_rng.randi_range(rect.position.x, rect.end.x - 1),
		_rng.randi_range(rect.position.y, rect.end.y - 1))
	var jitter := Vector3(_rng.randf_range(-1.1, 1.1), 0, _rng.randf_range(-1.1, 1.1))
	return _grid.cell_to_world(cell) + jitter

## Anything at least CUTAWAY_MIN_HEIGHT tall can hide the character from an
## isometric camera, so it joins the cutaway group automatically.
const CUTAWAY_MIN_HEIGHT := 1.5

func _box(parent_body: StaticBody3D, pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	if size.y >= CUTAWAY_MIN_HEIGHT:
		mi.add_to_group(&"cutaway_wall")
	add_child(mi)
	mi.global_position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	parent_body.add_child(shape)
	shape.global_position = pos

func _mat(color: Color, roughness: float, metallic: float, transparent: bool = false) -> StandardMaterial3D:
	var key := "%s_%f_%f_%s" % [color.to_html(), roughness, metallic, transparent]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m

# ---------------------------------------------------------------- environment

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.004, 0.006)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.65)
	env.ambient_light_energy = maxf(_floor_def.ambient_light * 1.6, 0.02)
	env.ssao_enabled = true
	env.ssil_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.15
	# The most important setting in the game (PLAN §13.1): light shafts
	# through doorways ARE the aesthetic.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = _floor_def.fog_density
	env.volumetric_fog_albedo = Color(0.7, 0.72, 0.75)
	env.volumetric_fog_emission_energy = 0.0
	env.volumetric_fog_anisotropy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	world_env.environment = env
	add_child(world_env)
