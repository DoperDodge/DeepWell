## The gaze system (PLAN §9.1) — the technical core of the game.
## Observation is a STRENGTH (0..1), not a bool: frustum, attention cone,
## occlusion, light level, and distance all factor in. At the edge of your
## vision, in a dark room, at 30 m, you only partially hold SCP-173 — it
## creeps. That creeping is the entire scare.
class_name PlayerGaze
extends Node

## Full render FOV is ~80°, but human ATTENTION is narrower. Beyond it you
## technically "see" but do not "observe".
@export var attention_cone_deg: float = 55.0
@export var peripheral_cone_deg: float = 78.0
## Peripheral observation is partial — enough to slow 173, not stop it.
@export var peripheral_effectiveness: float = 0.35

var _observed_now: Dictionary = {} # Node3D -> float strength
var _observed_last: Dictionary = {}
var _player: CharacterBody3D

func _ready() -> void:
	_player = get_parent() as CharacterBody3D
	add_to_group(&"gaze_observers") # NPC observers stack with you (PLAN §20.4)

func _physics_process(_delta: float) -> void:
	_observed_last = _observed_now
	_observed_now = {}
	if _player == null or _player.dead:
		_emit_transitions()
		return
	if _player.blink.is_blinking:
		_emit_transitions() # blinking breaks line of sight — 173's whole deal
		return
	for target in get_tree().get_nodes_in_group(&"observable"):
		var t3d := target as Node3D
		if t3d == null or not t3d.is_inside_tree():
			continue
		var strength := _evaluate(t3d)
		if strength > 0.0:
			_observed_now[t3d] = strength
	_emit_transitions()

func observation_strength(target: Node3D) -> float:
	return _observed_now.get(target, 0.0)

func is_observed(target: Node3D) -> bool:
	return observation_strength(target) > 0.05

func _evaluate(target: Node3D) -> float:
	var camera: Camera3D = _player.head.camera
	var point := target.get_node_or_null(^"ObservationPoint") as Node3D
	var world_pos := point.global_position if point != null else target.global_position

	# 1. Frustum test (cheap, do first)
	if not camera.is_position_in_frustum(world_pos):
		return 0.0

	# 2. Attention cone — narrower than the render frustum
	var to_target := world_pos - camera.global_position
	var dist := to_target.length()
	if dist < 0.01:
		return 1.0
	var forward := -camera.global_basis.z
	var angle := rad_to_deg(forward.angle_to(to_target / dist))
	var cone_factor := 0.0
	if angle <= attention_cone_deg * 0.5:
		cone_factor = 1.0
	elif angle <= peripheral_cone_deg * 0.5:
		cone_factor = peripheral_effectiveness
	else:
		return 0.0

	# 3. Occlusion raycast against world geometry only. The target's own
	# colliders are excluded — a statue must not hide behind itself.
	var space := _player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [_player.get_rid()]
	if target.has_method("get_occlusion_exclude_rids"):
		exclude.append_array(target.get_occlusion_exclude_rids())
	var q := PhysicsRayQueryParameters3D.create(camera.global_position, world_pos, 1, exclude)
	if not space.intersect_ray(q).is_empty():
		return 0.0

	# 4. Light level — you cannot observe what you cannot see. The player's
	# own flashlight is a registered probe light, so shining it at 173
	# genuinely holds it.
	var light := LightProbe.sample_at(world_pos)
	if light < 0.02:
		return 0.0
	var light_factor := clampf(remap(light, 0.02, 0.35, 0.0, 1.0), 0.0, 1.0)

	# 5. Distance falloff — full hold inside 8 m, fading to nothing at 40 m
	var dist_factor := clampf(remap(dist, 40.0, 8.0, 0.0, 1.0), 0.0, 1.0)

	return cone_factor * light_factor * dist_factor

func _emit_transitions() -> void:
	for t in _observed_now:
		if not _observed_last.has(t):
			EventBus.player_gaze_entered.emit(t)
	for t in _observed_last:
		if not _observed_now.has(t):
			EventBus.player_gaze_exited.emit(t)
