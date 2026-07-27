## Mouse look, head bob, lean, FOV (PLAN Phase 1). Sits on the Head node;
## yaw rotates the body, pitch rotates the head, lean rolls + offsets it.
class_name PlayerCamera
extends Node3D

const EYE_HEIGHT := 1.65
const EYE_HEIGHT_CROUCHED := 0.95
const LEAN_ANGLE_DEG := 14.0
const LEAN_OFFSET := 0.32
const PITCH_LIMIT := deg_to_rad(89.0)

var camera: Camera3D

var _player: CharacterBody3D
var _pitch: float = 0.0
var _lean: float = 0.0 # -1 left .. 1 right
var _bob_time: float = 0.0
var _shake: float = 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	camera = Camera3D.new()
	camera.fov = Settings.fov()
	camera.near = 0.05
	camera.far = 120.0
	camera.current = true
	add_child(camera)
	position = Vector3(0, EYE_HEIGHT, 0)

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _player.dead:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var sens := Settings.mouse_sensitivity()
		_player.rotate_y(-motion.relative.x * sens)
		_pitch = clampf(_pitch - motion.relative.y * sens, -PITCH_LIMIT, PITCH_LIMIT)

func _process(delta: float) -> void:
	if _player == null or _player.dead:
		return
	# Lean (Q / R): peeking is quieter than walking around the corner.
	var lean_target := 0.0
	if Input.is_action_pressed("lean_left"):
		lean_target = -1.0
	elif Input.is_action_pressed("lean_right"):
		lean_target = 1.0
	_lean = move_toward(_lean, lean_target, delta * 6.0)

	# Head bob synced to movement.
	var movement: PlayerMovement = _player.movement
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var bob_amp := 0.0
	if movement.is_moving and _player.is_on_floor():
		_bob_time += delta * speed * 1.6
		bob_amp = clampf(speed / PlayerMovement.SPEED_SPRINT, 0.0, 1.0) * 0.05 * Settings.head_bob()
	var bob_y := sin(_bob_time * TAU * 0.5) * bob_amp

	var eye := EYE_HEIGHT_CROUCHED if movement.crouched else EYE_HEIGHT
	position.y = lerpf(position.y, eye + bob_y, delta * 10.0)
	position.x = _lean * LEAN_OFFSET

	rotation.z = deg_to_rad(-_lean * LEAN_ANGLE_DEG)
	rotation.x = _pitch

	# Damage/scare shake, decaying.
	if _shake > 0.001:
		_shake = maxf(_shake - delta * 2.0, 0.0)
		var rng_offset := Vector3(
			sin(_bob_time * 91.0), cos(_bob_time * 83.0), 0.0) * _shake * 0.03
		camera.position = rng_offset
	else:
		camera.position = Vector3.ZERO

	# Sprint widens the view slightly; settings FOV is the base.
	var target_fov := Settings.fov() + (6.0 if movement.move_state == "sprint" and movement.is_moving else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, delta * 5.0)

func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)

func serialize() -> Dictionary:
	return {"pitch": _pitch, "yaw": _player.rotation.y}

func deserialize(d: Dictionary) -> void:
	_pitch = float(d.get("pitch", 0.0))
	_player.rotation.y = float(d.get("yaw", 0.0))
