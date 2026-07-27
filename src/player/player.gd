## D-9341. CharacterBody3D assembled from components (PLAN §5.4) — the same
## component scripts SCPs and NPCs reuse. Builds its own scene tree in code
## (see docs/ARCHITECTURE.md on why nothing is authored in the editor).
class_name Player
extends CharacterBody3D

const FLASHLIGHT_DRAIN_PER_S := 1.0 / 420.0 # ~7 minutes per battery

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

var flashlight: SpotLight3D
var flashlight_on: bool = false
var dead: bool = false

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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_body() -> void:
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.4
	_capsule.height = 1.8
	_collision = CollisionShape3D.new()
	_collision.shape = _capsule
	_collision.position.y = 0.9
	add_child(_collision)

	# First-person body: a visible torso/legs column in Class-D orange.
	# Looking down and seeing yourself matters (PLAN §13.5).
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.2
	mesh.height = 1.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.33, 0.08) # Class-D jumpsuit
	mat.roughness = 0.9
	mesh.material = mat
	body.mesh = mesh
	body.position.y = 0.65
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(body)

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
	head.add_child(flashlight)
	flashlight.position = Vector3(0.15, -0.12, 0.0)

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
	inventory.capacity_kg = 16.0 # 8 + strength(4) * 2 — Class-D start weak
	for c: Node in [movement, blink, gaze, interaction, needs, health, moodles, sanity, inventory]:
		add_child(c)

func _process(delta: float) -> void:
	if dead:
		return
	_update_flashlight(delta)
	# Walked distance for the termination report.
	var moved := global_position - _distance_accum
	moved.y = 0.0
	GameState.stats.distance_walked_m += moved.length()
	_distance_accum = global_position

func set_capsule_height(h: float) -> void:
	_capsule.height = h
	_collision.position.y = h * 0.5

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

func _update_flashlight(delta: float) -> void:
	if Input.is_action_just_pressed("flashlight"):
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
	FacilityState.record_player_death(GameState.floor_index, cell, cause, inventory.serialize())
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
	if bool(d.get("flashlight_on", false)):
		toggle_flashlight()
