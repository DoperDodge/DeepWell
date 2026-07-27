## SCP-1048 — "Builder Bear" · Euclid (PLAN §7.3). Comic relief that
## curdles: it waves, it follows, it leaves crayon drawings. The drawings
## get worse the more people have died in this site. Directly harmless.
class_name SCP1048
extends SCPBase

const WALK_SPEED := 0.85
const GREET_RANGE := 5.5

var _wander_target: Vector2i
var _path: Array[Vector2i] = []
var _greeting: bool = false
var _greet_cooldown: float = 0.0
var _follow_time: float = 0.0
var _met_player: bool = false
var _drawings_left: int = 3
var _bob_t: float = 0.0

func _init() -> void:
	designation = &"SCP-1048"
	nickname = "Builder Bear"
	persist_id = "scp_1048"
	hearing_threshold = 0.2

func observation_height() -> float:
	return 0.3

func _build_model() -> void:
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.45, 0.3, 0.16)
	fur.roughness = 1.0
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.12
	body_mesh.height = 0.34
	body_mesh.material = fur
	body.mesh = body_mesh
	body.position.y = 0.17
	add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.1
	head_mesh.height = 0.2
	head_mesh.material = fur
	head.mesh = head_mesh
	head.position.y = 0.4
	add_child(head)
	for x_sign in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var ear_mesh := SphereMesh.new()
		ear_mesh.radius = 0.04
		ear_mesh.height = 0.08
		ear_mesh.material = fur
		ear.mesh = ear_mesh
		ear.position = Vector3(x_sign * 0.07, 0.5, 0)
		add_child(ear)
	# A small area so the player can "greet" it back.
	var probe := StaticBody3D.new()
	probe.collision_layer = 4
	probe.collision_mask = 0
	probe.set_script(load("res://src/scps/scp_1048_touch.gd"))
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	shape.shape = sphere
	shape.position.y = 0.25
	probe.add_child(shape)
	add_child(probe)

func _process(delta: float) -> void:
	super._process(delta)
	if grid() == null or GameState.player == null:
		return
	var player := GameState.player
	_greet_cooldown -= delta
	_bob_t += delta

	if _greeting:
		# Face the player and bounce — a wave, in body language.
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		position.y = absf(sin(_bob_t * 9.0)) * 0.12
		return

	position.y = 0.0
	var dist := global_position.distance_to(player.global_position)
	if dist < GREET_RANGE and _greet_cooldown <= 0.0 \
			and grid().grid_line_clear(current_cell(), grid().world_to_cell(player.global_position)):
		_start_greeting(player)
		return

	if _follow_time > 0.0:
		_follow_time -= delta
		_step_along_path_to(grid().world_to_cell(player.global_position), delta)
		if dist < 3.0:
			return # keeps a polite distance
	else:
		if _wander_target == Vector2i.ZERO or current_cell() == _wander_target:
			_wander_target = grid().random_walkable_cell(RNG.stream(&"scp_1048_wander"))
			_path = []
		_step_along_path_to(_wander_target, delta)

func _step_along_path_to(target: Vector2i, delta: float) -> void:
	if _path.is_empty() or _path[-1] != target:
		_path = grid().find_path(current_cell(), target)
	if _path.size() < 2:
		return
	var next_world := grid().cell_to_world(_path[1])
	var to_next := next_world - global_position
	to_next.y = 0.0
	if to_next.length() < 0.3:
		_path.remove_at(0)
		return
	global_position += to_next.normalized() * WALK_SPEED * delta

func _start_greeting(player: Node3D) -> void:
	_greeting = true
	_greet_cooldown = 45.0
	AudioManager.play_3d(&"squeak", global_position, -8.0)
	if not _met_player:
		_met_player = true
		EventBus.toast.emit("The small bear waves at you.")
		player.sanity.adjust(-3.0) # something about it is wrong
	else:
		player.sanity.adjust(-1.0)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_callback(func() -> void:
		_greeting = false
		_maybe_leave_drawing()
		if RNG.stream(&"scp_1048").randf() < 0.35:
			_follow_time = RNG.stream(&"scp_1048").randf_range(20.0, 40.0))

func _maybe_leave_drawing() -> void:
	if _drawings_left <= 0 or RNG.stream(&"scp_1048").randf() > 0.6:
		return
	# The drawings darken with the site's body count (PLAN §16.3 worldbuild).
	var stage := clampi(FacilityState.site_deaths, 0, 2)
	var doc_id := StringName("doc_1048_drawing_%d" % (3 - _drawings_left + stage))
	if DocumentDB.get_doc(doc_id).is_empty():
		doc_id = StringName("doc_1048_drawing_0")
	_drawings_left -= 1
	var pickup := DocumentPickup.create("drawing_%d" % _drawings_left, doc_id)
	get_parent().add_child(pickup)
	pickup.global_position = global_position + Vector3(0.4, 0.0, 0.4)
	AudioManager.play_3d(&"paper", global_position, -12.0)

func serialize_state() -> Dictionary:
	var d := super.serialize_state()
	d["met"] = _met_player
	d["drawings_left"] = _drawings_left
	return d

func deserialize_state(d: Dictionary) -> void:
	super.deserialize_state(d)
	_met_player = bool(d.get("met", false))
	_drawings_left = int(d.get("drawings_left", 3))
