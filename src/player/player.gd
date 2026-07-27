## D-9341. CharacterBody3D assembled from components (PLAN §5.4) — the same
## component scripts SCPs and NPCs reuse. Played Project Zomboid-style: an
## isometric camera watches the character, WASD moves screen-relative, and
## the character FACES THE MOUSE — the facing cone is your vision, and your
## vision is what holds SCP-173.
class_name Player
extends CharacterBody3D

const FLASHLIGHT_DRAIN_PER_S := 1.0 / 420.0 # ~7 minutes per battery
const REACH_M := 3.2

var head: PlayerCamera
var movement: PlayerMovement
var blink: PlayerBlink
var gaze: PlayerGaze
var interaction: PlayerInteraction
var needs: NeedsComponent
var health: HealthComponent
var moodles: MoodleSystem
var sanity: SanitySystem
var inventory: Inventory
var skills: SkillSystem

var flashlight: SpotLight3D
var flashlight_on: bool = false
## Thermal goggles (SCP-966 counter): tunnel vision, battery, and the only
## way to see what has been following you since Floor 2.
var thermal_on: bool = false
var dead: bool = false

## When true the mouse stops steering the character — for scripted beats
## and for headless tests that aim deliberately.
var facing_locked: bool = false

var _visual: Node3D # rotates to face the mouse; body meshes + flashlight
var _facing: Vector3 = Vector3.FORWARD
var _capsule: CapsuleShape3D
var _collision: CollisionShape3D
var _distance_accum: Vector3

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 8 # world + doors
	_build_body()
	_build_components()
	health.died.connect(_on_died)
	_distance_accum = global_position
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # the cursor IS the aim

func _build_body() -> void:
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.4
	_capsule.height = 1.8
	_collision = CollisionShape3D.new()
	_collision.shape = _capsule
	_collision.position.y = 0.9
	add_child(_collision)

	# The visible character: Class-D orange jumpsuit, head, and a subtle
	# brow line so the facing reads at a glance from above.
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color(0.75, 0.33, 0.08)
	suit.roughness = 0.9
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.28
	body_mesh.height = 1.35
	body_mesh.material = suit
	body.mesh = body_mesh
	body.position.y = 0.75
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_visual.add_child(body)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.82, 0.66, 0.52)
	skin.roughness = 0.85
	var head_mesh_instance := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.14
	head_mesh.height = 0.28
	head_mesh.material = skin
	head_mesh_instance.mesh = head_mesh
	head_mesh_instance.position.y = 1.58
	_visual.add_child(head_mesh_instance)
	var brow := MeshInstance3D.new()
	var brow_mesh := BoxMesh.new()
	brow_mesh.size = Vector3(0.16, 0.05, 0.06)
	var brow_mat := StandardMaterial3D.new()
	brow_mat.albedo_color = Color(0.25, 0.18, 0.12)
	brow_mesh.material = brow_mat
	brow.mesh = brow_mesh
	brow.position = Vector3(0, 1.62, -0.12)
	_visual.add_child(brow)

	head = PlayerCamera.new()
	head.name = "Head"
	add_child(head)

	flashlight = SpotLight3D.new()
	flashlight.spot_range = 16.0
	flashlight.spot_angle = 32.0
	flashlight.light_energy = 2.4
	flashlight.light_color = Color(1.0, 0.96, 0.88)
	flashlight.shadow_enabled = true
	flashlight.visible = false
	_visual.add_child(flashlight) # the beam follows your facing
	flashlight.position = Vector3(0.12, 1.25, -0.2)
	flashlight.rotation.x = deg_to_rad(-4.0)

func _build_components() -> void:
	movement = PlayerMovement.new()
	blink = PlayerBlink.new()
	gaze = PlayerGaze.new()
	interaction = PlayerInteraction.new()
	needs = NeedsComponent.new()
	health = HealthComponent.new()
	moodles = MoodleSystem.new()
	sanity = SanitySystem.new()
	inventory = Inventory.new()
	skills = SkillSystem.new()
	inventory.capacity_kg = 16.0 # 8 + strength(4) * 2 — Class-D start weak
	for c: Node in [movement, blink, gaze, interaction, needs, health, moodles, sanity, inventory, skills]:
		add_child(c)
	_apply_occupation_kit()

## Whatever your old life left you (PLAN §10.8), smuggled through intake.
func _apply_occupation_kit() -> void:
	match GameState.occupation:
		&"medic":
			inventory.add_item(ItemInstance.new(&"bandage"))
			inventory.add_item(ItemInstance.new(&"disinfectant"))
		&"burglar":
			inventory.add_item(ItemInstance.new(&"crowbar"))
		&"electrician":
			inventory.add_item(ItemInstance.new(&"wire_spool"))
		&"chemist":
			inventory.add_item(ItemInstance.new(&"disinfectant"))

func _process(delta: float) -> void:
	if dead:
		return
	_update_facing()
	_update_flashlight(delta)
	_update_thermal(delta)
	# Walked distance for the termination report.
	var moved := global_position - _distance_accum
	moved.y = 0.0
	GameState.stats.distance_walked_m += moved.length()
	_distance_accum = global_position

## PZ rule: the character looks where the mouse points.
func _update_facing() -> void:
	if GameState.ui_blocking or facing_locked:
		return
	var cam := head.camera if head != null else null
	if cam == null or not cam.is_inside_tree():
		return
	var mouse := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mouse)
	var direction := cam.project_ray_normal(mouse)
	if absf(direction.y) < 0.001:
		return
	var t := (global_position.y + 1.0 - origin.y) / direction.y
	if t <= 0.0:
		return
	var target := origin + direction * t
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.35:
		return # cursor on top of the character: keep last facing
	set_facing(to_target.normalized())

func set_facing(dir: Vector3) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return
	_facing = dir.normalized()
	_visual.rotation.y = atan2(_facing.x, _facing.z) + PI

## The direction the character is looking — drives the gaze cone (173!),
## the flashlight, and the fallback interaction reach.
func facing_dir() -> Vector3:
	return _facing

func eye_position() -> Vector3:
	return global_position + Vector3.UP * 1.55

func set_capsule_height(h: float) -> void:
	_capsule.height = h
	_collision.position.y = h * 0.5
	_visual.scale.y = h / 1.8

## Every player stat the moodle system can threshold on (PLAN §10.1).
func get_stat(stat: StringName) -> float:
	match stat:
		&"hunger", &"thirst", &"fatigue", &"boredom", &"unhappiness", &"stress", &"panic":
			return needs.get_value(stat)
		&"pain":
			return health.total_pain()
		&"bleeding":
			return clampf(health.total_bleeding() * 45.0, 0.0, 100.0)
		&"sickness":
			return health.sickness
		&"infection":
			return health.worst_infection()
		&"injury":
			return 100.0 - health.overall_health()
		&"blood_loss":
			return 100.0 - health.blood
		&"winded":
			return 100.0 - movement.stamina
		&"encumbrance":
			return clampf(inventory.total_weight() / maxf(inventory.capacity_kg, 0.01) * 100.0, 0.0, 135.0)
		&"sanity_low":
			return 100.0 - sanity.sanity
		&"feverish":
			return health.pestilence_progress()
	return 0.0

func toggle_flashlight() -> void:
	var light_item := inventory.first_of_category(&"light")
	if light_item == null:
		EventBus.toast.emit("You have no flashlight.")
		return
	if not flashlight_on and light_item.charge <= 0.0:
		EventBus.toast.emit("The flashlight battery is dead.")
		AudioManager.play_ui(&"ui_click", -12.0)
		return
	flashlight_on = not flashlight_on
	flashlight.visible = flashlight_on
	AudioManager.play_ui(&"ui_click", -10.0)
	if flashlight_on:
		flashlight.add_to_group(&"probe_light") # light betrays you (§9.4)
	else:
		flashlight.remove_from_group(&"probe_light")

func toggle_thermal() -> void:
	var goggles := inventory.first_of_category(&"goggles")
	if goggles == null:
		EventBus.toast.emit("You have no thermal goggles.")
		return
	if not thermal_on and goggles.charge <= 0.0:
		EventBus.toast.emit("The goggles' cell is flat.")
		return
	thermal_on = not thermal_on
	AudioManager.play_ui(&"ui_click", -8.0, 0.8)
	# Goggles murder your peripheral attention (PLAN §7.3: "severely
	# restrict peripheral vision") — 173 gets easier to lose.
	gaze.attention_cone_deg = 34.0 if thermal_on else 60.0
	gaze.peripheral_cone_deg = 44.0 if thermal_on else 110.0

func _update_thermal(delta: float) -> void:
	if not thermal_on:
		return
	var goggles := inventory.first_of_category(&"goggles")
	if goggles == null:
		toggle_thermal()
		return
	goggles.charge = maxf(goggles.charge - delta / 300.0, 0.0)
	if goggles.charge <= 0.0:
		toggle_thermal()
		EventBus.toast.emit("The thermal goggles die.")

func _update_flashlight(delta: float) -> void:
	if Input.is_action_just_pressed("flashlight") and not GameState.ui_blocking:
		toggle_flashlight()
	if not flashlight_on:
		return
	var light_item := inventory.first_of_category(&"light")
	if light_item == null:
		toggle_flashlight()
		return
	light_item.charge = maxf(light_item.charge - FLASHLIGHT_DRAIN_PER_S * delta, 0.0)
	# Color temperature slides white -> amber as the battery dies (§13.2).
	var c := light_item.charge
	flashlight.light_energy = lerpf(0.7, 2.4, clampf(c * 3.0, 0.15, 1.0))
	flashlight.light_color = Color(1.0, lerpf(0.72, 0.96, c), lerpf(0.45, 0.88, c))
	if c <= 0.0:
		toggle_flashlight()
		EventBus.toast.emit("The flashlight dies.")

## Instant death (173's neck snap, catastrophic events).
func kill(cause: String) -> void:
	if dead:
		return
	health.damage(&"neck", &"instant_death", 999.0)
	_finalize_death(cause)

func _on_died(cause: String) -> void:
	_finalize_death(cause)

func _finalize_death(cause: String) -> void:
	if dead and cause != "":
		pass
	dead = true
	flashlight_on = false
	flashlight.visible = false
	var cell := Vector2i.ZERO
	if GameState.grid != null:
		cell = GameState.grid.world_to_cell(global_position)
	FacilityState.record_player_death(GameState.floor_index, cell, cause, inventory.serialize(),
		health.has_pestilence() or cause.contains("Pestilence") or cause.contains("anomalous etiology"))
	EventBus.player_died.emit(cause, GameState.floor_index, global_position)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func serialize() -> Dictionary:
	return {
		"pos": [global_position.x, global_position.y, global_position.z],
		"camera": head.serialize(),
		"movement": movement.serialize(),
		"needs": needs.serialize(),
		"health": health.serialize(),
		"sanity": sanity.serialize(),
		"inventory": inventory.serialize(),
		"skills": skills.serialize(),
		"flashlight_on": flashlight_on,
	}

func deserialize(d: Dictionary) -> void:
	var p: Array = d.get("pos", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
	head.deserialize(d.get("camera", {}))
	movement.deserialize(d.get("movement", {}))
	needs.deserialize(d.get("needs", {}))
	health.deserialize(d.get("health", {}))
	sanity.deserialize(d.get("sanity", {}))
	inventory.deserialize(d.get("inventory", []))
	skills.deserialize(d.get("skills", {}))
	if bool(d.get("flashlight_on", false)):
		toggle_flashlight()
