## Interaction, Project Zomboid-style: you point at things with the mouse.
## The cursor picks the target; the target must still be within arm's reach
## of the character, so you cannot loot across a room. Holding [E] runs
## timed actions (searching, prying) — which root you in place, in the open,
## making noise.
class_name PlayerInteraction
extends Node

const REACH_M := 3.2
## world + interactable + door + pickup layers
const RAY_MASK := 1 | 4 | 8 | 32

var current_target: Node = null
var current_prompt: String = ""
var hold_progress: float = -1.0 # -1 = not holding

var _player: CharacterBody3D
var _hold_target: Node = null
var _hold_time: float = 0.0
var _hold_needed: float = 0.0
var _rummage_timer: float = 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody3D

func _physics_process(delta: float) -> void:
	if _player == null or _player.dead or GameState.ui_blocking:
		current_prompt = ""
		current_target = null
		hold_progress = -1.0
		return
	current_target = _find_target()
	current_prompt = ""
	if current_target != null:
		current_prompt = current_target.get_prompt(_player)

	if _hold_target != null:
		_continue_hold(delta)
	elif Input.is_action_just_pressed("interact") and current_target != null:
		_begin(current_target)

func _begin(target: Node) -> void:
	var duration: float = target.interact_duration() if target.has_method("interact_duration") else 0.0
	if duration <= 0.0:
		target.interact(_player)
		return
	# Practice makes faster hands (PLAN §10.7 Scavenging).
	duration *= 1.0 - 0.03 * _player.skills.level(&"scavenging")
	if GameState.occupation == &"burglar":
		duration *= 0.6
	_hold_target = target
	_hold_needed = maxf(duration, 0.4)
	_hold_time = 0.0
	_rummage_timer = 0.0

func _continue_hold(delta: float) -> void:
	var still_valid := Input.is_action_pressed("interact") and current_target == _hold_target
	if not still_valid:
		_cancel_hold()
		return
	_hold_time += delta
	hold_progress = _hold_time / _hold_needed
	_rummage_timer -= delta
	if _rummage_timer <= 0.0:
		_rummage_timer = 0.45
		# Rummaging is audible (PLAN §10.9) — searching draws attention.
		AudioManager.play_3d(&"paper", _player.global_position, -14.0)
		EventBus.noise_emitted.emit(_player.global_position, 0.2, _player, ["rummage"])
	if _hold_time >= _hold_needed:
		var target := _hold_target
		_cancel_hold()
		if target is WorldContainer or target is Corpse:
			_player.skills.add_xp(&"scavenging", 20.0)
		target.interact(_player)

func _cancel_hold() -> void:
	_hold_target = null
	hold_progress = -1.0

## Cursor first (what you point at), facing ray as fallback (what you walk
## into). Both are range-limited to the character, never the camera.
func _find_target() -> Node:
	var by_cursor := _target_under_cursor()
	if by_cursor != null:
		return by_cursor
	return _target_ahead()

func _target_under_cursor() -> Node:
	var camera: Camera3D = _player.head.camera
	if camera == null or not camera.is_inside_tree():
		return null
	var mouse: Vector2 = _player.get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse) * 200.0
	var hit := _raycast(from, to)
	if hit.is_empty():
		return null
	# Reach is measured from the character, not the camera.
	if _player.global_position.distance_to(hit.position) > REACH_M:
		return null
	return _interactable_from(hit.collider)

func _target_ahead() -> Node:
	var from: Vector3 = _player.eye_position()
	var facing: Vector3 = _player.facing_dir()
	var to := from + facing * REACH_M
	var hit := _raycast(from, to)
	if hit.is_empty():
		return null
	return _interactable_from(hit.collider)

func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var space := _player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK, [_player.get_rid()])
	q.collide_with_areas = true
	return space.intersect_ray(q)

func _interactable_from(collider: Object) -> Node:
	var node := collider as Node
	# Walk up the tree: colliders are often children of the scripted entity.
	while node != null:
		if node.has_method("get_prompt") and node.has_method("interact"):
			return node
		node = node.get_parent()
	return null
