## SCP-049 — "The Plague Doctor" · Euclid · Floor 4 (PLAN §7.3).
## Sapient, articulate, polite — and utterly convinced you are infected.
## His touch is not damage; it is a death sequence. He is slow. He does not
## stop. Doors are not an obstacle to a doctor on his rounds.
class_name SCP049
extends SCPBase

const WALK_SPEED := 1.05
const SIGHT_RANGE := 19.0
const TOUCH_RANGE := 1.5

var _path: Array[Vector2i] = []
var _target_cell: Vector2i
var _chasing: bool = false
var _lost_timer: float = 0.0
var _line_cooldown: float = 0.0
var _door_cooldown: float = 0.0

const LINES_NOTICE := [
	"Ah. There you are. I could smell it on you from across the ward.",
	"Do not run from your physician. The Pestilence makes men irrational.",
	"You are very sick, my friend. Fortunately, I am the cure.",
]
const LINES_CLOSE := [
	"Hold still. The procedure is brief.",
	"This will only take a moment. You will thank me. They all would have.",
	"Shhh. The fever speaks, not you.",
]
const LINES_LOST := [
	"Hiding only lets it spread...",
	"I have such patience. Sickness has none.",
]

func _init() -> void:
	designation = &"SCP-049"
	nickname = "The Plague Doctor"
	persist_id = "scp_049"
	hearing_threshold = 0.05

func observation_height() -> float:
	return 1.7

func _build_model() -> void:
	# Tall robed figure, pale beaked mask — original primitive design.
	var robe := StandardMaterial3D.new()
	robe.albedo_color = Color(0.07, 0.06, 0.07)
	robe.roughness = 0.95
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.34
	body_mesh.height = 1.9
	body_mesh.material = robe
	body.mesh = body_mesh
	body.position.y = 0.95
	add_child(body)
	var mask_mat := StandardMaterial3D.new()
	mask_mat.albedo_color = Color(0.9, 0.88, 0.82)
	mask_mat.roughness = 0.4
	var head_mesh_instance := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.14
	head_mesh.height = 0.28
	head_mesh.material = mask_mat
	head_mesh_instance.mesh = head_mesh
	head_mesh_instance.position.y = 1.78
	add_child(head_mesh_instance)
	var beak := MeshInstance3D.new()
	var beak_mesh := PrismMesh.new()
	beak_mesh.size = Vector3(0.09, 0.3, 0.09)
	beak_mesh.material = mask_mat
	beak.mesh = beak_mesh
	beak.position = Vector3(0, 1.74, -0.2)
	beak.rotation.x = -PI * 0.5
	add_child(beak)
	var hat := MeshInstance3D.new()
	var hat_mesh := CylinderMesh.new()
	hat_mesh.top_radius = 0.19
	hat_mesh.bottom_radius = 0.19
	hat_mesh.height = 0.07
	hat_mesh.material = robe
	hat.mesh = hat_mesh
	hat.position.y = 1.93
	add_child(hat)
	# Solid presence: players should not phase through the Doctor.
	var collider := StaticBody3D.new()
	collider.collision_layer = 1 | 16
	collider.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.95
	collider.add_child(shape)
	add_child(collider)

func _process(delta: float) -> void:
	super._process(delta)
	var player := GameState.player
	if player == null or grid() == null or player.dead:
		return
	_line_cooldown -= delta
	_door_cooldown -= delta
	var dist := global_position.distance_to(player.global_position)

	if _can_see(player, dist):
		if not _chasing:
			_chasing = true
			_say(LINES_NOTICE)
			if not witnessed:
				witnessed = true
				EventBus.scp_witnessed.emit(designation)
			player.needs.spike_panic(35.0)
			Director.report_scare(0.5)
		_target_cell = grid().world_to_cell(player.global_position)
		_lost_timer = 0.0
	elif _chasing:
		_lost_timer += delta
		if _lost_timer > 20.0:
			_chasing = false
			_say(LINES_LOST)
	elif _time - last_heard_at < 10.0 and last_heard_loudness > 0.1:
		_target_cell = grid().world_to_cell(last_heard_position)

	if _chasing and dist < 7.0 and _line_cooldown <= 0.0:
		_say(LINES_CLOSE)

	if _chasing and dist <= TOUCH_RANGE:
		# The cure (PLAN §7.3: touch = death, not a damage number).
		player.health.contract_pestilence()
		AudioManager.play_ui(&"heartbeat", 0.0, 0.6)
		Director.report_scare(1.0)
		FacilityState.log_incident("Subject %s received treatment from SCP-049. Subject pronounced cured." % GameState.designation)
		player.kill("cardiac arrest of anomalous etiology")
		return

	if _target_cell != Vector2i.ZERO and (_chasing or _target_cell != current_cell()):
		var pressure := maxf(Director.stalk_pressure(), 0.4) if _chasing else 1.0
		_walk_toward(_target_cell, WALK_SPEED * minf(pressure, 1.25), delta)
	elif _target_cell == Vector2i.ZERO:
		_target_cell = grid().random_walkable_cell(RNG.stream(&"scp_049_patrol"))

func _can_see(player: Node3D, dist: float) -> bool:
	if dist > SIGHT_RANGE:
		return false
	if not grid().grid_line_clear(current_cell(), grid().world_to_cell(player.global_position)):
		return false
	return LightProbe.sample_at(player.global_position + Vector3.UP * 1.2) > 0.035

## The Doctor walks his rounds THROUGH doors — locked ones open for him
## (canon: cooperative, escorted, and containment keeps failing around him).
## Welded doors alone hold. This is the counterplay lesson.
func _walk_toward(target: Vector2i, speed: float, delta: float) -> void:
	if _path.is_empty() or _path[-1] != target:
		_path = grid().find_path_open(current_cell(), target)
	if _path.size() < 2:
		return
	var my_cell := current_cell()
	var next: Vector2i = _path[1]
	if _path[0] != my_cell:
		_path = grid().find_path_open(my_cell, target)
		if _path.size() < 2:
			return
		next = _path[1]
	if grid().has_door(my_cell, next) and not grid().is_door_open(my_cell, next):
		if _door_cooldown <= 0.0:
			_door_cooldown = 1.2
			var door := grid().door_node(my_cell, next)
			if door != null:
				door.force_open_for_entity()
		return # wait for the door
	var next_world := grid().cell_to_world(next)
	var to_next := next_world - global_position
	to_next.y = 0.0
	if to_next.length() < 0.35:
		_path.remove_at(0)
		return
	global_position += to_next.normalized() * speed * delta
	# Slow, unhurried footfalls. You can always hear the Doctor coming.
	if int(_time * 1.4) != int((_time - delta) * 1.4):
		AudioManager.play_3d(&"footstep_concrete_0", global_position, -16.0, 0.7)
		EventBus.noise_emitted.emit(global_position, 0.2, self, ["footstep"])

func _say(lines: Array) -> void:
	if _line_cooldown > 0.0:
		return
	_line_cooldown = 14.0
	var line: String = lines[RNG.stream(&"scp_049_voice").randi_range(0, lines.size() - 1)]
	EventBus.subtitle.emit("SCP-049", line)

func serialize_state() -> Dictionary:
	var d := super.serialize_state()
	d["chasing"] = _chasing
	return d

func deserialize_state(d: Dictionary) -> void:
	super.deserialize_state(d)
	_chasing = bool(d.get("chasing", false))
