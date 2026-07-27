## A door on a grid edge (PLAN §6.4): LOCKED / UNLOCKED / OPEN / JAMMED /
## POWERED_DOWN / WELDED. Standard doors slide; blast doors are slower and
## louder. A powered-down door can be pried with a crowbar — slow and loud.
## State persists via FacilityState and mirrors into the grid nav graph.
class_name Door
extends Node3D

enum DoorState { LOCKED, UNLOCKED, OPEN, JAMMED, POWERED_DOWN, WELDED }

const CLEARANCE_COLORS := [
	Color(0.55, 0.55, 0.55), # L0 grey
	Color(0.92, 0.92, 0.92), # L1 white
	Color(0.25, 0.5, 0.95),  # L2 blue
	Color(0.2, 0.75, 0.4),   # L3 green
	Color(0.95, 0.6, 0.15),  # L4 orange
	Color(0.9, 0.2, 0.2),    # L5 red
]

var door_id: String
var cell_a: Vector2i
var cell_b: Vector2i
var clearance: int = 0
var is_blast: bool = false
var state: int = DoorState.UNLOCKED

var _panel: StaticBody3D
var _panel_mesh: MeshInstance3D
var _grid: FacilityGrid
var _open_offset: Vector3
var _closed_pos: Vector3
var _busy: bool = false

## Called by the generator before adding to the tree.
func setup(grid: FacilityGrid, a: Vector2i, b: Vector2i, p_clearance: int, blast: bool, initial_state: int) -> void:
	_grid = grid
	cell_a = a
	cell_b = b
	clearance = p_clearance
	is_blast = blast
	state = initial_state
	door_id = "door_%d_%d__%d_%d" % [a.x, a.y, b.x, b.y]
	# Restore persisted state (welded stays welded, opened stays open).
	if FacilityState.door_states.has(door_id):
		state = int(FacilityState.door_states[door_id])

func _ready() -> void:
	var wall_t := 0.24
	var opening_w := 3.0 if is_blast else 1.4
	var opening_h := 3.0 if is_blast else 2.4
	var cell := FacilityGrid.CELL_SIZE

	# Position on the shared edge, rotated so local X runs along the wall.
	var wa := _grid.cell_to_world(cell_a)
	var wb := _grid.cell_to_world(cell_b)
	global_position = (wa + wb) * 0.5
	if cell_a.y != cell_b.y:
		rotation.y = PI * 0.5 # edge normal along Z -> wall runs along X

	# Wall segments flanking the opening + header above it.
	var side_w := (cell - opening_w) * 0.5
	for sign_x in [-1.0, 1.0]:
		_add_static_box(
			Vector3(sign_x * (opening_w * 0.5 + side_w * 0.5), 1.6, 0.0),
			Vector3(side_w, 3.2, wall_t), _wall_material())
	_add_static_box(
		Vector3(0.0, opening_h + (3.2 - opening_h) * 0.5, 0.0),
		Vector3(opening_w, 3.2 - opening_h, wall_t), _wall_material())

	# The sliding panel.
	_panel = StaticBody3D.new()
	_panel.collision_layer = 8
	_panel.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(opening_w, opening_h, wall_t * 0.6)
	shape.shape = box
	_panel.add_child(shape)
	_panel_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.34, 0.36) if not is_blast else Color(0.2, 0.21, 0.23)
	mat.metallic = 0.7
	mat.roughness = 0.45
	mesh.material = mat
	_panel_mesh.mesh = mesh
	_panel.add_child(_panel_mesh)
	add_child(_panel)
	shape.position = Vector3(0, opening_h * 0.5, 0)
	_panel_mesh.position = Vector3(0, opening_h * 0.5, 0)
	_closed_pos = Vector3.ZERO
	_open_offset = Vector3(opening_w * 0.96, 0, 0)

	# Clearance stripe + label on both faces.
	var stripe_color: Color = CLEARANCE_COLORS[clampi(clearance, 0, 5)]
	for z_sign in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = ("LEVEL %d" % clearance) if clearance > 0 else ("BLAST DOOR" if is_blast else "")
		label.font_size = 40
		label.modulate = stripe_color
		label.position = Vector3(0, opening_h + 0.35, z_sign * (wall_t * 0.5 + 0.01))
		label.rotation.y = 0.0 if z_sign > 0 else PI
		add_child(label)

	_apply_state_visual(true)

func _wall_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.56, 0.58)
	m.roughness = 0.85
	return m

func _add_static_box(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)
	body.position = pos

# ---------------------------------------------------------------- interact

func get_prompt(player: Node) -> String:
	match state:
		DoorState.OPEN:
			return "[E] Close door"
		DoorState.UNLOCKED:
			return "[E] Open door"
		DoorState.LOCKED:
			if GameState.clearance >= clearance:
				return "[E] Swipe keycard (Level %d)" % clearance
			return "LOCKED — requires Level %d keycard" % clearance
		DoorState.POWERED_DOWN:
			if _has_crowbar(player):
				return "[E] (hold) Pry door — no power"
			return "NO POWER — a crowbar could pry this open"
		DoorState.JAMMED:
			if _has_crowbar(player):
				return "[E] (hold) Force jammed door"
			return "JAMMED — needs a crowbar"
		DoorState.WELDED:
			return "WELDED SHUT"
	return ""

func interact_duration() -> float:
	if state == DoorState.POWERED_DOWN or state == DoorState.JAMMED:
		return 3.0
	return 0.0

func interact(player: Node) -> void:
	if _busy:
		return
	match state:
		DoorState.OPEN:
			_close()
		DoorState.UNLOCKED:
			_open_door()
		DoorState.LOCKED:
			if GameState.clearance >= clearance:
				AudioManager.play_3d(&"keycard_ok", global_position, -8.0)
				state = DoorState.UNLOCKED
				_persist()
				_open_door()
			else:
				AudioManager.play_3d(&"keycard_deny", global_position, -8.0)
				EventBus.noise_emitted.emit(global_position, 0.15, self, ["beep"])
		DoorState.POWERED_DOWN, DoorState.JAMMED:
			if _has_crowbar(player):
				_pry()
			else:
				AudioManager.play_3d(&"door_locked", global_position, -10.0)
		DoorState.WELDED:
			pass

func _has_crowbar(player: Node) -> bool:
	return player != null and "inventory" in player and player.inventory.has_item(&"crowbar")

func _open_door() -> void:
	_busy = true
	state = DoorState.OPEN
	_persist()
	AudioManager.play_3d(&"door_open", global_position, -6.0)
	EventBus.noise_emitted.emit(global_position, 0.9 if is_blast else 0.3, self, ["door"])
	var tw := create_tween()
	tw.tween_property(_panel, "position", _open_offset, 1.6 if is_blast else 0.7)
	tw.tween_callback(func() -> void: _busy = false)
	_panel.collision_layer = 0
	_grid.set_door_open(cell_a, cell_b, true)

func _close() -> void:
	_busy = true
	state = DoorState.UNLOCKED
	_persist()
	AudioManager.play_3d(&"door_close", global_position, -6.0)
	EventBus.noise_emitted.emit(global_position, 0.35, self, ["door"])
	var tw := create_tween()
	tw.tween_property(_panel, "position", _closed_pos, 0.6)
	tw.tween_callback(func() -> void:
		_busy = false
		_panel.collision_layer = 8)
	_grid.set_door_open(cell_a, cell_b, false)

func _pry() -> void:
	# Prying is the loudest thing you can do short of an alarm (PLAN §6.4).
	AudioManager.play_3d(&"door_pry", global_position, -2.0)
	EventBus.noise_emitted.emit(global_position, 0.6, self, ["pry", "metal"])
	state = DoorState.UNLOCKED
	_persist()
	_open_door()

func _persist() -> void:
	FacilityState.door_states[door_id] = state
	EventBus.door_state_changed.emit(StringName(door_id), state)

func _apply_state_visual(initial: bool) -> void:
	if state == DoorState.OPEN:
		_panel.position = _open_offset
		_panel.collision_layer = 0
		_grid.set_door_open(cell_a, cell_b, true)
	elif initial:
		_panel.position = _closed_pos
		_grid.set_door_open(cell_a, cell_b, false)
