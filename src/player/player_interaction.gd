## Interaction raycast with prompts and hold-to-interact (PLAN Phase 1).
## Anything with get_prompt()/interact() is interactable; a positive
## interact_duration() means you stand still, vulnerable, while a progress
## ring fills — searching a desk is a commitment.
class_name PlayerInteraction
extends Node

const REACH_M := 2.5
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
	_hold_target = target
	_hold_needed = duration
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
		target.interact(_player)

func _cancel_hold() -> void:
	_hold_target = null
	hold_progress = -1.0

func _find_target() -> Node:
	var camera: Camera3D = _player.head.camera
	var space := _player.get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_basis.z * REACH_M
	var q := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK, [_player.get_rid()])
	q.collide_with_areas = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return null
	var node: Node = hit.collider
	# Walk up the tree: colliders are often children of the scripted entity.
	while node != null:
		if node.has_method("get_prompt") and node.has_method("interact"):
			return node
		node = node.get_parent()
	return null
