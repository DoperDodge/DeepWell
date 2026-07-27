## SCP-049-2 — the Doctor's "cured" (PLAN §7.3). Slow, groaning, reanimated
## staff — and, on this floor, reanimated *you*: a pestilent corpse from a
## previous run rises wearing your predecessor's jumpsuit, standing guard
## over its own body and everything you died carrying (PLAN §20.1).
class_name SCP049_2
extends SCPBase

const SHAMBLE_SPEED := 0.75
const CHASE_SPEED := 1.5
const ATTACK_RANGE := 1.35
const ATTACK_INTERVAL := 1.3
const BITE_PESTILENCE_CHANCE := 0.35

## Cell it lingers near when idle (its corpse, or its spawn point).
var anchor_cell: Vector2i = Vector2i.ZERO
## Non-empty when this instance rose from a previous player's corpse.
var risen_designation: String = ""

var _path: Array[Vector2i] = []
var _chasing: bool = false
var _attack_timer: float = 0.0
var _groan_timer: float = 5.0
var _recognized: bool = false
var _speed_jitter: float = 1.0

func _init() -> void:
	designation = &"SCP-049-2"
	nickname = "instance"
	persist_id = "scp_049_2"
	hearing_threshold = 0.12

func observation_height() -> float:
	return 1.5

func _build_model() -> void:
	_speed_jitter = RNG.stream(&"scp_049_2").randf_range(0.85, 1.25)
	var flesh := StandardMaterial3D.new()
	flesh.albedo_color = Color(0.5, 0.55, 0.45)
	flesh.roughness = 0.95
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color(0.75, 0.33, 0.08) if risen_designation != "" else Color(0.8, 0.8, 0.78)
	suit.roughness = 0.9
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.26
	body_mesh.height = 1.55
	body_mesh.material = suit
	body.mesh = body_mesh
	body.position.y = 0.85
	body.rotation.x = 0.18 # the hunch
	add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.12
	head_mesh.height = 0.26
	head_mesh.material = flesh
	head.mesh = head_mesh
	head.position = Vector3(0, 1.62, -0.12)
	add_child(head)
	# Crude surgical sutures: a dark seam across the chest.
	var seam := MeshInstance3D.new()
	var seam_mesh := BoxMesh.new()
	seam_mesh.size = Vector3(0.34, 0.05, 0.02)
	var seam_mat := StandardMaterial3D.new()
	seam_mat.albedo_color = Color(0.2, 0.05, 0.05)
	seam_mesh.material = seam_mat
	seam.mesh = seam_mesh
	seam.position = Vector3(0, 1.2, -0.26)
	add_child(seam)

func _process(delta: float) -> void:
	super._process(delta)
	var player := GameState.player
	if player == null or grid() == null or player.dead:
		return
	_attack_timer -= delta
	_groan_timer -= delta
	var dist := global_position.distance_to(player.global_position)

	if _groan_timer <= 0.0:
		_groan_timer = RNG.stream(&"scp_049_2").randf_range(4.0, 11.0)
		if dist < 30.0:
			AudioManager.play_3d(&"groan", global_position, -10.0, _speed_jitter)
			EventBus.noise_emitted.emit(global_position, 0.18, self, ["groan"])

	# Mostly blind; hunts noise and close movement (PLAN §7.3 "attritional").
	var sees := dist < 8.0 and grid().grid_line_clear(current_cell(), grid().world_to_cell(player.global_position))
	var heard := _time - last_heard_at < 8.0 and last_heard_loudness > hearing_threshold
	_chasing = sees or heard

	if risen_designation != "" and not _recognized and dist < 6.0 and sees:
		_recognized = true
		EventBus.toast.emit("It is wearing %s's jumpsuit. It was you." % risen_designation)
		player.sanity.adjust(-12.0)
		player.needs.spike_panic(40.0)

	if _chasing and dist <= ATTACK_RANGE:
		if _attack_timer <= 0.0:
			_attack_timer = ATTACK_INTERVAL
			_attack(player)
		return

	if _chasing:
		var target := grid().world_to_cell(player.global_position) if sees else grid().world_to_cell(last_heard_position)
		_shamble_toward(target, CHASE_SPEED * _speed_jitter, delta)
	else:
		# Linger near the anchor — its corpse, its old life.
		if anchor_cell == Vector2i.ZERO:
			anchor_cell = current_cell()
		var wander := anchor_cell + Vector2i(
			RNG.stream(&"scp_049_2").randi_range(-2, 2), RNG.stream(&"scp_049_2").randi_range(-2, 2))
		if grid().is_walkable(wander) and current_cell().distance_squared_to(anchor_cell) > 16:
			_shamble_toward(anchor_cell, SHAMBLE_SPEED, delta)
		elif grid().is_walkable(wander):
			_shamble_toward(wander, SHAMBLE_SPEED * 0.6, delta)

func _attack(player: Node3D) -> void:
	var rng := RNG.stream(&"scp_049_2")
	var is_bite := rng.randf() < 0.4
	var part: StringName = [&"arm_l", &"arm_r", &"torso_upper", &"hand_l", &"hand_r"][rng.randi_range(0, 4)]
	AudioManager.play_3d(&"thud", global_position, -8.0, 1.2)
	EventBus.noise_emitted.emit(global_position, 0.3, self, ["attack"])
	if is_bite:
		player.health.damage(part, &"bite", rng.randf_range(6.0, 11.0))
		if rng.randf() < BITE_PESTILENCE_CHANCE:
			player.health.contract_pestilence() # you won't know for two hours
	else:
		player.health.damage(part, &"cut", rng.randf_range(5.0, 10.0))
	player.needs.spike_panic(30.0)
	player.head.shake(0.7)

func _shamble_toward(target: Vector2i, speed: float, delta: float) -> void:
	if _path.is_empty() or _path[-1] != target:
		_path = grid().find_path(current_cell(), target) # cannot open doors
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
	d["anchor"] = [anchor_cell.x, anchor_cell.y]
	d["risen"] = risen_designation
	return d

func deserialize_state(d: Dictionary) -> void:
	super.deserialize_state(d)
	var a: Array = d.get("anchor", [0, 0])
	anchor_cell = Vector2i(int(a[0]), int(a[1]))
	risen_designation = d.get("risen", "")
