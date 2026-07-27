## Isometric wall cutaway (the Project Zomboid "you can see into the room"
## trick). Any tagged wall or tall prop sitting between the camera and the
## character fades out, so the player is never hidden behind the geometry
## they are standing next to. Ceilings are never built at all — same reason
## PZ hides roofs.
##
## Cheap by construction: candidates are distance-filtered, the occlusion
## pass runs at 15 Hz, and only currently-faded meshes are eased per frame.
class_name WallCutaway
extends Node

const TICK_INTERVAL := 1.0 / 15.0
## Only geometry within this radius of the character can ever be cut.
const CANDIDATE_RADIUS := 14.0
## How close to the camera->character line a wall must be to occlude.
const OCCLUDE_RADIUS := 3.6
const FADE_SPEED := 6.0
const MAX_TRANSPARENCY := 0.92

var _tick: float = 0.0
## MeshInstance3D -> {"current": float, "target": float}
var _tracked: Dictionary = {}

func _process(delta: float) -> void:
	var player := GameState.player
	var camera: Camera3D = null
	if player != null and is_instance_valid(player) and player.is_inside_tree():
		camera = player.head.camera if player.head != null else null

	if camera == null or not camera.is_inside_tree():
		_clear_targets() # world tearing down: let everything fade back in
	else:
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK_INTERVAL
			_recompute(player, camera)
	_apply_fades(delta)

func _recompute(player: Node3D, camera: Camera3D) -> void:
	var cam_pos := camera.global_position
	var target_pos := player.global_position + Vector3.UP * 1.0
	var forward := target_pos - cam_pos
	var span := forward.length()
	if span < 0.01:
		return
	forward /= span

	for entry in _tracked.values():
		entry.target = 0.0

	for node in get_tree().get_nodes_in_group(&"cutaway_wall"):
		var mesh := node as GeometryInstance3D
		if mesh == null or not mesh.is_inside_tree():
			continue
		var pos := mesh.global_position
		if pos.distance_squared_to(target_pos) > CANDIDATE_RADIUS * CANDIDATE_RADIUS:
			continue
		# Only geometry in front of the character (nearer the camera) can
		# hide them, and only if it sits close to the sight line.
		var to_mesh := pos - cam_pos
		var along := to_mesh.dot(forward)
		if along <= 0.0 or along >= span:
			continue
		if (to_mesh - forward * along).length() > OCCLUDE_RADIUS:
			continue
		if _tracked.has(mesh):
			_tracked[mesh].target = MAX_TRANSPARENCY
		else:
			_tracked[mesh] = {"current": 0.0, "target": MAX_TRANSPARENCY}

func _apply_fades(delta: float) -> void:
	for mesh in _tracked.keys():
		var geometry := mesh as GeometryInstance3D
		if geometry == null or not is_instance_valid(geometry) or not geometry.is_inside_tree():
			_tracked.erase(mesh)
			continue
		var entry: Dictionary = _tracked[mesh]
		entry.current = move_toward(entry.current, entry.target, FADE_SPEED * delta)
		geometry.transparency = entry.current
		# Hard cut once nearly gone: guarantees the cutaway reads even if
		# per-instance transparency is unavailable on the render path.
		geometry.visible = entry.current < MAX_TRANSPARENCY - 0.01
		if entry.target <= 0.0 and entry.current <= 0.001:
			geometry.transparency = 0.0
			geometry.visible = true
			_tracked.erase(mesh)

func _clear_targets() -> void:
	for entry in _tracked.values():
		entry.target = 0.0
