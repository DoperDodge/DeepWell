## "How lit is this point?" (PLAN §9.4). Drives 173's observation checks,
## sanity drain in darkness, and the flashlight tradeoff. Godot doesn't
## expose this cheaply, so we sum contributions from registered lights with
## distance/cone falloff and an occlusion raycast, cached for 0.2 s.
##
## Lights participate by joining the "probe_light" group.
extends Node

const CACHE_SECONDS := 0.2
const CACHE_BUCKET := 1.0 # meters — quantization of query points

## Per-floor ambient light floor (Floor 1 = 0.4 … Floor 7 = 0.0).
var ambient_floor: float = 0.08

var _cache: Dictionary = {} # Vector3i -> {t: float, v: float}
var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	if _cache.size() > 4096:
		_cache.clear()

func sample_at(world_pos: Vector3) -> float:
	var key := Vector3i((world_pos / CACHE_BUCKET).round())
	var hit: Dictionary = _cache.get(key, {})
	if not hit.is_empty() and _time - float(hit.t) < CACHE_SECONDS:
		return hit.v
	var v := _sample_uncached(world_pos)
	_cache[key] = {"t": _time, "v": v}
	return v

func _sample_uncached(world_pos: Vector3) -> float:
	var total := ambient_floor
	var space: PhysicsDirectSpaceState3D = null
	var world := _current_world()
	if world != null:
		space = world.direct_space_state
	for l in get_tree().get_nodes_in_group(&"probe_light"):
		var light := l as Light3D
		if light == null or not light.visible or not light.is_inside_tree():
			continue
		var contribution := _light_contribution(light, world_pos)
		if contribution <= 0.005:
			continue
		# Occlusion: a light behind a wall doesn't light you.
		if space != null:
			var q := PhysicsRayQueryParameters3D.create(
				light.global_position, world_pos, 1) # world geometry layer only
			var ray := space.intersect_ray(q)
			if not ray.is_empty() and ray.position.distance_to(world_pos) > 0.6:
				continue
		total += contribution
	return clampf(total, 0.0, 1.0)

func _light_contribution(light: Light3D, world_pos: Vector3) -> float:
	var to_point := world_pos - light.global_position
	var dist := to_point.length()
	if light is OmniLight3D:
		var omni := light as OmniLight3D
		if dist >= omni.omni_range:
			return 0.0
		var falloff := 1.0 - dist / omni.omni_range
		return omni.light_energy * falloff * falloff * 0.6
	if light is SpotLight3D:
		var spot := light as SpotLight3D
		if dist >= spot.spot_range:
			return 0.0
		var forward := -spot.global_basis.z
		var angle := rad_to_deg(forward.angle_to(to_point.normalized()))
		if angle > spot.spot_angle:
			return 0.0
		var cone := 1.0 - angle / maxf(spot.spot_angle, 0.01)
		var falloff := 1.0 - dist / spot.spot_range
		return spot.light_energy * falloff * falloff * cone * 0.7
	return 0.0

func _current_world() -> World3D:
	var scene := get_tree().current_scene
	if scene is Node3D:
		return (scene as Node3D).get_world_3d()
	if GameState.player != null and GameState.player.is_inside_tree():
		return GameState.player.get_world_3d()
	return null
