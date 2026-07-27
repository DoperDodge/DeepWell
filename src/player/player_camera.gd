## Project Zomboid-style isometric follow camera: fixed 45° yaw, steep
## pitch, mouse-wheel zoom, smooth follow. Replaces the first-person rig —
## the character is watched, not inhabited. The class keeps its old name so
## the player's `head` wiring stays intact.
class_name PlayerCamera
extends Node3D

const YAW := deg_to_rad(45.0)
const PITCH := deg_to_rad(-54.0)
const ZOOM_MIN := 8.0
const ZOOM_MAX := 22.0
const ZOOM_DEFAULT := 13.0
const FOLLOW_SPEED := 7.0

var camera: Camera3D
var zoom: float = ZOOM_DEFAULT

var _player: CharacterBody3D
var _snapped: bool = false
var _shake: float = 0.0
var _shake_t: float = 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	top_level = true # follow smoothly; never inherit the body's motion
	camera = Camera3D.new()
	camera.fov = 35.0
	camera.near = 0.5
	camera.far = 160.0
	camera.current = true
	add_child(camera)
	if _player != null:
		global_position = _player.global_position
	rotation = Vector3(PITCH, YAW, 0.0)
	_apply_zoom()

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if not _snapped:
		# The player's spawn position is assigned after _ready(), so the
		# first frame snaps instead of easing in from the origin.
		_snapped = true
		global_position = _player.global_position + Vector3.UP * 1.0
	if not GameState.ui_blocking:
		if Input.is_action_just_pressed("zoom_in"):
			zoom = clampf(zoom - 1.4, ZOOM_MIN, ZOOM_MAX)
			_apply_zoom()
		elif Input.is_action_just_pressed("zoom_out"):
			zoom = clampf(zoom + 1.4, ZOOM_MIN, ZOOM_MAX)
			_apply_zoom()
	global_position = global_position.lerp(
		_player.global_position + Vector3.UP * 1.0, minf(delta * FOLLOW_SPEED, 1.0))
	if _shake > 0.001:
		_shake = maxf(_shake - delta * 2.0, 0.0)
		_shake_t += delta * 60.0
		camera.h_offset = sin(_shake_t * 1.7) * _shake * 0.12
		camera.v_offset = cos(_shake_t * 1.3) * _shake * 0.12
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func _apply_zoom() -> void:
	camera.position = Vector3(0, 0, zoom)

## Screen-relative movement basis: camera yaw only, flattened.
func move_basis() -> Basis:
	return Basis(Vector3.UP, YAW)

func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)

func serialize() -> Dictionary:
	return {"zoom": zoom}

func deserialize(d: Dictionary) -> void:
	zoom = clampf(float(d.get("zoom", ZOOM_DEFAULT)), ZOOM_MIN, ZOOM_MAX)
	_apply_zoom()
