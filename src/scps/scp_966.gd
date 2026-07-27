## SCP-966 — "Sleeper" · Euclid · Floor 2 (PLAN §7.3).
## Invisible in the visible spectrum — not translucent, not shimmering,
## NOTHING — and plainly visible in infrared. Its presence murders your
## rest; it closes in when you are exhausted or standing still. The best
## moment in the game: you put on the goggles in a corridor you've walked
## six times, and it is standing there. Watching.
class_name SCP966
extends SCPBase

const STALK_SPEED := 0.95
const RUSH_SPEED := 3.2
const AURA_RADIUS := 25.0
const PREFERRED_RANGE := 9.0

var _mode: String = "stalk" # stalk | rush | retreat
var _aura_timer: float = 0.0
var _still_time: float = 0.0
var _last_player_pos: Vector3
var _retreat_target: Vector2i
var _path: Array[Vector2i] = []
var _breath_timer: float = 8.0
var _seen_under_thermal: bool = false

func _init() -> void:
	designation = &"SCP-966"
	nickname = "Sleeper"
	persist_id = "scp_966"
	hearing_threshold = 0.06

var _model: Node3D

func observation_height() -> float:
	return 1.4

func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	# Emaciated, sinewy, long-limbed — rendered white-hot for the thermal
	# ramp. Original design from article text only.
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(0.95, 0.95, 0.92)
	hot.emission_enabled = true
	hot.emission = Color(1.0, 0.98, 0.9)
	hot.emission_energy_multiplier = 2.2
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.16
	torso_mesh.height = 1.5
	torso_mesh.material = hot
	torso.mesh = torso_mesh
	torso.position.y = 0.95
	_model.add_child(torso)
	var skull := MeshInstance3D.new()
	var skull_mesh := SphereMesh.new()
	skull_mesh.radius = 0.11
	skull_mesh.height = 0.26
	skull_mesh.material = hot
	skull.mesh = skull_mesh
	skull.position.y = 1.78
	_model.add_child(skull)
	for arm_sign in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.045
		arm_mesh.height = 1.15
		arm_mesh.material = hot
		arm.mesh = arm_mesh
		arm.position = Vector3(arm_sign * 0.28, 1.05, 0.1)
		arm.rotation.z = arm_sign * 0.28
		arm.rotation.x = -0.35
		_model.add_child(arm)
	# INVISIBLE in the visible spectrum. This is the whole entity.
	_model.visible = false
	remove_from_group(&"observable")

func _process(delta: float) -> void:
	super._process(delta)
	var player := GameState.player
	if player == null or grid() == null or player.dead:
		return
	_update_visibility(player)
	_update_aura(player, delta)
	_breath_timer -= delta
	var dist := global_position.distance_to(player.global_position)
	if _breath_timer <= 0.0 and dist < 14.0:
		_breath_timer = RNG.stream(&"scp_966").randf_range(6.0, 14.0)
		# Faint wet breathing from empty air. Players learn this sound.
		AudioManager.play_3d(&"whisper", global_position, -20.0, 0.6)

	if player.global_position.distance_to(_last_player_pos) < 0.4:
		_still_time += delta
	else:
		_still_time = 0.0
		_last_player_pos = player.global_position

	match _mode:
		"stalk":
			_stalk(player, delta, dist)
		"rush":
			_rush(player, delta, dist)
		"retreat":
			_retreat(delta)

func _update_visibility(player: Node) -> void:
	var thermal: bool = player.thermal_on
	if thermal == _model.visible:
		return
	_model.visible = thermal
	if thermal:
		add_to_group(&"observable")
		if not _seen_under_thermal:
			_seen_under_thermal = true
			EventBus.scp_witnessed.emit(designation)
			player.needs.spike_panic(55.0)
			player.sanity.adjust(-10.0)
			Director.report_scare(0.8)
			EventBus.toast.emit("It has been here the whole time.")
	else:
		remove_from_group(&"observable")

## Insomnia field (canon): fatigue cannot recover near it, and climbs.
func _update_aura(player: Node, delta: float) -> void:
	_aura_timer += delta
	if _aura_timer < 1.0:
		return
	_aura_timer = 0.0
	if global_position.distance_to(player.global_position) < AURA_RADIUS:
		player.needs.adjust(&"fatigue", 0.55)
		player.sanity.adjust(-0.1)

func _stalk(player: Node3D, delta: float, dist: float) -> void:
	# Holds a polite distance — until you are exhausted or you stop moving.
	var exhausted: bool = player.needs.get_value(&"fatigue") > 65.0
	if (exhausted or _still_time > 6.0) and dist < 18.0:
		_mode = "rush"
		return
	var target := grid().world_to_cell(player.global_position)
	if dist < PREFERRED_RANGE - 2.0:
		_step_away(player, delta)
	elif dist > PREFERRED_RANGE + 3.0:
		_move_along(target, STALK_SPEED * Director.stalk_pressure() * 0.8 + 0.3, delta)

func _rush(player: Node3D, delta: float, dist: float) -> void:
	if dist > 1.7:
		_move_along(grid().world_to_cell(player.global_position), RUSH_SPEED, delta)
		return
	# Contact: a raking scratch, a shriek from nowhere, and gone.
	AudioManager.play_3d(&"shriek", global_position, -2.0)
	EventBus.noise_emitted.emit(global_position, 0.5, self, ["shriek"])
	var arm := &"arm_l" if RNG.stream(&"scp_966").randf() < 0.5 else &"arm_r"
	player.health.damage(arm, &"cut", RNG.stream(&"scp_966").randf_range(7.0, 13.0))
	player.needs.spike_panic(60.0)
	player.head.shake(1.0)
	Director.report_scare(0.9)
	_retreat_target = grid().random_walkable_cell(RNG.stream(&"scp_966"))
	_mode = "retreat"

func _retreat(delta: float) -> void:
	if current_cell() == _retreat_target or _retreat_target == Vector2i.ZERO:
		_mode = "stalk"
		return
	_move_along(_retreat_target, RUSH_SPEED * 0.8, delta)

func _step_away(player: Node3D, delta: float) -> void:
	var away := (global_position - player.global_position)
	away.y = 0.0
	if away.length() < 0.1:
		return
	var candidate := global_position + away.normalized() * STALK_SPEED * delta
	if grid().is_walkable(grid().world_to_cell(candidate)):
		global_position = candidate

func _move_along(target: Vector2i, speed: float, delta: float) -> void:
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
	global_position += to_next.normalized() * speed * delta

func serialize_state() -> Dictionary:
	var d := super.serialize_state()
	d["seen_thermal"] = _seen_under_thermal
	return d

func deserialize_state(d: Dictionary) -> void:
	super.deserialize_state(d)
	_seen_under_thermal = bool(d.get("seen_thermal", false))
