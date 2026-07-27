## First-person movement (PLAN §19 Phase 1, constants §23): walk / sprint /
## crouch / lean / jump, stamina, fall damage, and the footstep noise +
## audio cadence. Injury and encumbrance genuinely slow you — a broken leg
## is a mobility event, not a number.
class_name PlayerMovement
extends Node

const SPEED_CROUCH := 1.1
const SPEED_WALK := 2.2
const SPEED_RUN := 4.0
const SPEED_SPRINT := 6.0
const STAMINA_MAX := 100.0
const STAMINA_SPRINT_COST := 12.0
const STAMINA_JUMP_COST := 8.0
const STAMINA_REGEN := 6.0
const STAMINA_REGEN_DELAY := 1.5
const GRAVITY := 9.8
const JUMP_VELOCITY := 3.4

const LOUDNESS := {
	"crouch": 0.08,
	"walk": 0.25,
	"run": 0.55,
	"sprint": 0.85,
}

var stamina: float = STAMINA_MAX

func stamina_max() -> float:
	var bonus := 30.0 if GameState.occupation == &"athlete" else 0.0
	return STAMINA_MAX + bonus + _player.skills.level(&"fitness") * 8.0
var crouched: bool = false
var move_state: String = "walk" # crouch|walk|run|sprint (current gait)
var is_moving: bool = false

var _player: CharacterBody3D
var _regen_delay: float = 0.0
var _step_accum: float = 0.0
var _fall_peak_speed: float = 0.0
var _was_on_floor: bool = true
var _footstep_rng := RandomNumberGenerator.new()
var _sprint_time: float = 0.0
var _wheeze_timer: float = 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	_footstep_rng.seed = 20347 # cosmetic variation only — not run RNG

func _physics_process(delta: float) -> void:
	if _player == null or _player.dead:
		return
	if GameState.ui_blocking:
		_player.velocity.x = 0.0
		_player.velocity.z = 0.0
		if not _player.is_on_floor():
			_player.velocity.y -= GRAVITY * get_physics_process_delta_time()
		_player.move_and_slide()
		return
	_handle_crouch()
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (_player.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	is_moving = direction.length_squared() > 0.01 and _player.is_on_floor()

	var wants_sprint := Input.is_action_pressed("sprint") and not crouched
	var encumbrance: int = _player.inventory.encumbrance_tier()
	var speed := _current_speed(wants_sprint, encumbrance)

	if move_state == "sprint" and is_moving:
		stamina = maxf(stamina - STAMINA_SPRINT_COST * delta, 0.0)
		_regen_delay = STAMINA_REGEN_DELAY
		_player.needs.exertion = 2.5
		_sprint_time += delta
		_player.skills.add_xp(&"fitness", delta * 2.0)
	else:
		# Asthmatic: a long sprint buys you a loud, involuntary wheeze after.
		if GameState.has_trait(&"asthmatic") and _sprint_time > 3.0:
			_wheeze_timer = 4.0
			_sprint_time = 0.0
		elif _sprint_time > 0.0 and move_state != "sprint":
			_sprint_time = 0.0
		_player.needs.exertion = 1.4 if (move_state == "run" and is_moving) else 1.0
		_regen_delay -= delta
		if _regen_delay <= 0.0:
			var regen := STAMINA_REGEN
			if _player.needs.get_value(&"fatigue") > 80.0:
				regen *= 0.4
			stamina = minf(stamina + regen * delta, stamina_max())

	if not _player.is_on_floor():
		_player.velocity.y -= GRAVITY * delta
		_fall_peak_speed = maxf(_fall_peak_speed, -_player.velocity.y)
	elif Input.is_action_just_pressed("jump") and stamina > STAMINA_JUMP_COST and not crouched:
		_player.velocity.y = JUMP_VELOCITY
		stamina -= STAMINA_JUMP_COST
		_regen_delay = STAMINA_REGEN_DELAY
		_emit_footstep(0.35) # takeoff scuff

	if direction != Vector3.ZERO:
		_player.velocity.x = direction.x * speed
		_player.velocity.z = direction.z * speed
	else:
		_player.velocity.x = move_toward(_player.velocity.x, 0, speed * 8.0 * delta)
		_player.velocity.z = move_toward(_player.velocity.z, 0, speed * 8.0 * delta)

	if _wheeze_timer > 0.0:
		_wheeze_timer -= delta
		if fmod(_wheeze_timer, 1.3) < delta:
			AudioManager.play_3d(&"wheeze", _player.global_position, -8.0)
			EventBus.noise_emitted.emit(_player.global_position, 0.3, _player, ["wheeze", "human"])

	_player.move_and_slide()
	_check_landing()
	_footsteps(delta, speed)

func _current_speed(wants_sprint: bool, encumbrance: int) -> float:
	var mobility: float = _player.health.leg_mobility()
	var enc_mult := 1.0
	if encumbrance == 1:
		enc_mult = 0.85
	elif encumbrance == 2:
		enc_mult = 0.6
	if crouched:
		move_state = "crouch"
		return SPEED_CROUCH * mobility * enc_mult
	if wants_sprint and stamina > 4.0 and encumbrance == 0 and mobility > 0.6:
		move_state = "sprint"
		var sprint_speed := SPEED_SPRINT + (0.6 if GameState.occupation == &"athlete" else 0.0)
		return sprint_speed * mobility
	if wants_sprint:
		move_state = "run" # too winded/laden to sprint — downgraded, still loud
		return SPEED_RUN * mobility * enc_mult
	move_state = "walk"
	return SPEED_WALK * mobility * enc_mult

func _handle_crouch() -> void:
	if Input.is_action_just_pressed("crouch"):
		if crouched and _ceiling_blocked():
			return
		crouched = not crouched
		_player.set_capsule_height(1.1 if crouched else 1.8)

func _ceiling_blocked() -> bool:
	var space := _player.get_world_3d().direct_space_state
	var from := _player.global_position + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 1.5, 1)
	return not space.intersect_ray(q).is_empty()

func _check_landing() -> void:
	var on_floor := _player.is_on_floor()
	if on_floor and not _was_on_floor and _fall_peak_speed > 7.0:
		# Fall damage to the legs; ~7 m/s is a >2.5 m drop.
		var dmg := (_fall_peak_speed - 6.0) * 9.0
		var leg := &"leg_lower_l" if _footstep_rng.randf() < 0.5 else &"leg_lower_r"
		_player.health.damage(leg, &"fall", dmg)
		EventBus.noise_emitted.emit(_player.global_position, 0.6, _player, ["impact"])
		AudioManager.play_3d(&"thud", _player.global_position, -4.0)
	if on_floor:
		_fall_peak_speed = 0.0
	_was_on_floor = on_floor

func _footsteps(delta: float, speed: float) -> void:
	if not is_moving or not _player.is_on_floor():
		_step_accum = 0.4
		return
	_step_accum += speed * delta
	var stride := 1.9 if move_state == "sprint" else 1.5
	if crouched:
		stride = 1.0
	if _step_accum >= stride:
		_step_accum = 0.0
		_emit_footstep(current_loudness())
		if crouched:
			_player.skills.add_xp(&"lightfooted", 1.0)

func current_loudness() -> float:
	var loudness: float = LOUDNESS.get(move_state, 0.25)
	if _player.inventory.encumbrance_tier() >= 2:
		loudness = minf(loudness + 0.15, 1.0) # heavy load is loud (§10.1)
	if GameState.has_trait(&"light_step"):
		loudness *= 0.75
	if GameState.occupation == &"burglar":
		loudness *= 0.6
	# Lightfooted: trained by sneaking, up to -40% (PLAN §10.7 — "the single
	# most valuable skill in this game").
	loudness *= 1.0 - 0.04 * _player.skills.level(&"lightfooted")
	return maxf(loudness, 0.03)

func _emit_footstep(loudness: float) -> void:
	EventBus.noise_emitted.emit(_player.global_position, loudness, _player, ["footstep", "human"])
	var mat := _floor_material()
	var variant: int = _footstep_rng.randi_range(0, 3 if mat == "concrete" else 1)
	var volume := lerpf(-26.0, -8.0, loudness)
	AudioManager.play_3d(StringName("footstep_%s_%d" % [mat, variant]),
		_player.global_position, volume, _footstep_rng.randf_range(0.92, 1.08))

func _floor_material() -> String:
	var space := _player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		_player.global_position + Vector3.UP * 0.3, _player.global_position + Vector3.DOWN * 0.6, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and hit.collider != null and hit.collider.has_meta("footstep_mat"):
		return str(hit.collider.get_meta("footstep_mat"))
	return "concrete"

func serialize() -> Dictionary:
	return {"stamina": stamina, "crouched": crouched}

func deserialize(d: Dictionary) -> void:
	stamina = float(d.get("stamina", STAMINA_MAX))
	if bool(d.get("crouched", false)) != crouched:
		crouched = bool(d.get("crouched", false))
		_player.set_capsule_height(1.1 if crouched else 1.8)
