## The gaze system (PLAN §9.1) — the technical core of the game, in its
## Project Zomboid form: observation comes from the CHARACTER's vision cone
## (where you point the mouse), not from the camera frustum.
##
## This makes the isometric view genuinely scarier than first person: you
## can SEE SCP-173 on your screen, standing in a corridor to your left,
## while your character is looking the other way — and because your
## character is not observing it, it moves. You have to physically point at
## a thing to hold it.
##
## Observation is a STRENGTH (0..1): cone angle, occlusion, light level, and
## distance all factor in. At the cone's edge, in a dark room, at 30 m, you
## only partially hold it. It creeps. That creeping is the entire scare.
class_name PlayerGaze
extends Node

## Full attention: dead ahead of the character (PZ's focused vision).
@export var attention_cone_deg: float = 60.0
## Peripheral: still technically seen, not properly observed.
@export var peripheral_cone_deg: float = 110.0
@export var peripheral_effectiveness: float = 0.35

## Light response. Below BLIND you genuinely cannot see; above FULL the
## light is no longer the limiting factor.
const LIGHT_BLIND_BELOW := 0.012
const LIGHT_FULL_ABOVE := 0.18
const LIGHT_MIN_FACTOR := 0.2

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
	var point := target.get_node_or_null(^"ObservationPoint") as Node3D
	var world_pos := point.global_position if point != null else target.global_position
	var eye: Vector3 = _player.eye_position()

	# 1. Vision cone from the character's facing (the mouse direction).
	var to_target := world_pos - eye
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var dist := to_target.length()
	if dist < 0.01:
		return 1.0
	if flat.length() < 0.01:
		return 1.0 # directly overhead/underfoot
	var facing: Vector3 = _player.facing_dir()
	var angle := rad_to_deg(facing.angle_to(flat.normalized()))
	var cone_factor := 0.0
	if angle <= attention_cone_deg * 0.5:
		cone_factor = 1.0
	elif angle <= peripheral_cone_deg * 0.5:
		cone_factor = peripheral_effectiveness
	else:
		return 0.0 # behind you. It is free to move.

	# 2. Occlusion raycast against world geometry only. The target's own
	# colliders are excluded — a statue must not hide behind itself.
	var space := _player.get_world_3d().direct_space_state
	var exclude: Array[RID] = [_player.get_rid()]
	if target.has_method("get_occlusion_exclude_rids"):
		exclude.append_array(target.get_occlusion_exclude_rids())
	var q := PhysicsRayQueryParameters3D.create(eye, world_pos, 1, exclude)
	if not space.intersect_ray(q).is_empty():
		return 0.0

	# 3. Light level — you cannot observe what you cannot see. In pitch
	# blackness you hold nothing; in gloom you hold it weakly (it creeps);
	# under a working fixture or your own flashlight beam you hold it
	# completely. This is why the flashlight is the answer to SCP-173.
	var light := LightProbe.sample_at(world_pos)
	if light < LIGHT_BLIND_BELOW:
		return 0.0
	var light_factor := clampf(
		remap(light, LIGHT_BLIND_BELOW, LIGHT_FULL_ABOVE, LIGHT_MIN_FACTOR, 1.0),
		LIGHT_MIN_FACTOR, 1.0)

	# 4. Distance falloff — full hold inside 8 m, fading to nothing at 40 m
	var dist_factor := clampf(remap(dist, 40.0, 8.0, 0.0, 1.0), 0.0, 1.0)

	return cone_factor * light_factor * dist_factor

func _emit_transitions() -> void:
	for t in _observed_now:
		if not _observed_last.has(t):
			EventBus.player_gaze_entered.emit(t)
	for t in _observed_last:
		if not _observed_now.has(t):
			EventBus.player_gaze_exited.emit(t)
