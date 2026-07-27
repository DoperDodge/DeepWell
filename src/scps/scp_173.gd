## SCP-173 — "The Sculpture" · Euclid (PLAN §7.3).
## Cannot move while within direct line of sight. Blinking counts. It does
## not lerp: you blink and it has moved four meters. Kill is instant.
##
## LICENSING (PLAN §2.3): this model is an ORIGINAL abstract design —
## an angular concrete monolith with exposed rebar, built from primitives.
## Nothing is derived from Izumi Kato's *Untitled 2004*. The article text
## ("concrete and rebar with traces of Krylon brand spray paint") is the
## only source.
class_name SCP173
extends SCPBase

const STEP_DISTANCE_CELLS := 1     # 1 cell = 4 m (PLAN §23 step distance)
const STEP_COOLDOWN := 0.12
const OBSERVED_FREEZE_THRESHOLD := 0.55
const KILL_RANGE := 1.9

var hunting: bool = false

var _step_timer: float = 0.0
var _residue: Array[Node3D] = []
var _wander_target: Vector2i
var _scare_cooldown: float = 0.0
var _rattle_cooldown: float = 0.0

func _init() -> void:
	designation = &"SCP-173"
	nickname = "The Sculpture"
	persist_id = "scp_173"
	hearing_threshold = 0.08

func observation_height() -> float:
	return 1.5

func _build_model() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1 | 16 # world (players collide) + scp
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 2.0
	shape.shape = capsule
	shape.position.y = 1.0
	body.add_child(shape)
	add_child(body)

	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.58, 0.57, 0.54)
	concrete.roughness = 0.95
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.65, 0.38, 0.1) # ochre spray traces
	paint.roughness = 0.9
	var rebar := StandardMaterial3D.new()
	rebar.albedo_color = Color(0.25, 0.2, 0.18)
	rebar.metallic = 0.6
	rebar.roughness = 0.5

	# Tilted, tapering monolith — deliberately not humanoid.
	_mesh_box(Vector3(0, 0.55, 0), Vector3(0.9, 1.1, 0.7), concrete, 0.0)
	_mesh_box(Vector3(0.05, 1.45, -0.03), Vector3(0.7, 0.9, 0.55), concrete, 0.08)
	var head := MeshInstance3D.new()
	var head_mesh := PrismMesh.new()
	head_mesh.size = Vector3(0.55, 0.6, 0.5)
	head_mesh.material = concrete
	head.mesh = head_mesh
	head.position = Vector3(0.02, 2.1, 0)
	head.rotation.z = 0.14
	add_child(head)
	# Paint traces: irregular patches, no face, no figure.
	_mesh_box(Vector3(0.2, 1.6, 0.26), Vector3(0.3, 0.35, 0.04), paint, 0.3)
	_mesh_box(Vector3(-0.25, 0.9, 0.33), Vector3(0.25, 0.5, 0.03), paint, -0.2)
	# Exposed rebar: bent rods from shoulders and base.
	for params in [[Vector3(0.35, 1.9, 0.1), 0.5], [Vector3(-0.4, 1.75, -0.1), 0.7], [Vector3(0.3, 0.15, 0.2), 0.4]]:
		var rod := MeshInstance3D.new()
		var rod_mesh := CylinderMesh.new()
		rod_mesh.top_radius = 0.02
		rod_mesh.bottom_radius = 0.02
		rod_mesh.height = params[1]
		rod_mesh.material = rebar
		rod.mesh = rod_mesh
		rod.position = params[0]
		rod.rotation.z = 0.9
		rod.rotation.x = 0.4
		add_child(rod)

func _mesh_box(pos: Vector3, size: Vector3, mat: StandardMaterial3D, tilt: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.z = tilt
	add_child(mi)

func _physics_process(delta: float) -> void:
	if GameState.player == null or grid() == null:
		return
	var player := GameState.player
	if player.dead:
		return
	_scare_cooldown -= delta
	_rattle_cooldown -= delta

	var strength := total_observation()
	if strength >= OBSERVED_FREEZE_THRESHOLD:
		# Frozen. Absolutely still — not even idle animation (PLAN §7.3).
		_step_timer = 0.0
		_close_range_dread(player, delta)
		return

	# Partial observation (peripheral, darkness, distance) slows it: the
	# step cooldown stretches as your hold on it weakens. It creeps.
	var cooldown := lerpf(STEP_COOLDOWN, 1.1, strength / OBSERVED_FREEZE_THRESHOLD)
	_step_timer += delta
	if _step_timer < cooldown:
		return
	_step_timer = 0.0
	_take_step(player)

func _take_step(player: Node3D) -> void:
	var my_cell := current_cell()
	var target_cell := _target_cell(player)
	if my_cell == target_cell:
		_try_kill(player)
		return
	var path := grid().find_path(my_cell, target_cell)
	if path.size() < 2:
		# Blocked (a closed door works — that is the counterplay). It tests
		# the door. You hear it.
		if hunting and _rattle_cooldown <= 0.0:
			_rattle_cooldown = 3.0
			AudioManager.play_3d(&"door_locked", global_position, -6.0)
			EventBus.noise_emitted.emit(global_position, 0.3, self, ["rattle"])
		return
	var next: Vector2i = path[1]
	var player_cell := grid().world_to_cell(player.global_position)
	if hunting and next == player_cell:
		# Steps onto you. There is no fight.
		global_position = player.global_position + (global_position - player.global_position).normalized() * 0.7
		_try_kill(player)
		return
	_leave_residue()
	global_position = grid().cell_to_world(next) + Vector3.UP * 0.02
	AudioManager.play_3d(&"stone_drag", global_position, -7.0)
	EventBus.noise_emitted.emit(global_position, 0.4, self, ["stone", "scrape"])

func _target_cell(player: Node3D) -> Vector2i:
	if not hunting:
		return home_cell
	var pressure := Director.stalk_pressure()
	if pressure <= 0.0:
		# Rest beat: the Director leashes it away from the player.
		if _wander_target == Vector2i.ZERO or current_cell() == _wander_target:
			_wander_target = grid().random_walkable_cell(RNG.stream(&"scp_173_wander"))
		return _wander_target
	# Heard something recent and loud? Investigate that instead of psychic
	# player tracking — misdirection must work (PLAN §12.2).
	if _time - last_heard_at < 12.0 and last_heard_loudness > 0.12:
		return grid().world_to_cell(last_heard_position)
	return grid().world_to_cell(player.global_position)

func _try_kill(player: Node3D) -> void:
	if global_position.distance_to(player.global_position) > KILL_RANGE * 2.5:
		return
	AudioManager.play_ui(&"neck_snap", 0.0)
	Director.report_scare(1.0)
	player.kill("cervical fracture, instantaneous")

func _close_range_dread(player: Node3D, delta: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	GameState.stats.closest_173_m = minf(GameState.stats.closest_173_m, dist)
	if dist < 10.0:
		player.sanity.adjust(-0.6 * delta)
	if dist < 7.0 and _scare_cooldown <= 0.0:
		_scare_cooldown = 25.0
		player.needs.spike_panic(45.0)
		Director.report_scare(0.7)

func _on_first_observed() -> void:
	if not hunting:
		hunting = true
		FacilityState.register_breach(designation)
		FacilityState.log_incident("Visual contact with SCP-173 reported by %s. Containment status: BREACHED." % GameState.designation)

func _on_heard(_pos: Vector3, loudness: float) -> void:
	# Loud noise wakes it even unseen. Sprinting past the chamber is a choice.
	if not hunting and loudness > 0.3:
		hunting = true
		FacilityState.register_breach(designation)

func _leave_residue() -> void:
	var decal := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 0.3
	mesh.height = 0.005
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.38, 0.1, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mesh.material = mat
	decal.mesh = mesh
	get_parent().add_child(decal)
	decal.global_position = global_position + Vector3(0, 0.012, 0)
	_residue.append(decal)
	if _residue.size() > 40:
		var oldest: Node3D = _residue.pop_front()
		oldest.queue_free()

func serialize_state() -> Dictionary:
	var d := super.serialize_state()
	d["hunting"] = hunting
	return d

func deserialize_state(d: Dictionary) -> void:
	super.deserialize_state(d)
	hunting = bool(d.get("hunting", false))
