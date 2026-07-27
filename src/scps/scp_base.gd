## Base for all anomalies: observable registration, hearing (via the noise
## graph), grid movement helpers, persistence, and the witnessed event that
## feeds the Anomaly Log. Perception components mirror the player's — the
## same rules apply to everything (PLAN §5.4).
class_name SCPBase
extends Node3D

var designation: StringName = &"SCP-000"
var nickname: String = ""
var persist_id: String = ""

var home_cell: Vector2i
var witnessed: bool = false

## Hearing blackboard (PLAN §12.2): investigate, don't teleport.
var last_heard_position: Vector3 = Vector3.ZERO
var last_heard_loudness: float = 0.0
var last_heard_at: float = -1000.0
var hearing_threshold: float = 0.05

var _time: float = 0.0

func _ready() -> void:
	add_to_group(&"observable")
	add_to_group(&"persistable")
	var obs_point := Node3D.new()
	obs_point.name = "ObservationPoint"
	add_child(obs_point)
	obs_point.position = Vector3(0, observation_height(), 0)
	EventBus.noise_emitted.connect(_on_noise)
	EventBus.player_gaze_entered.connect(_on_gaze_entered)
	_build_model()

func _process(delta: float) -> void:
	_time += delta

## Subclasses build their (original-design) bodies here.
func _build_model() -> void:
	pass

func observation_height() -> float:
	return 1.6

func grid() -> FacilityGrid:
	return GameState.grid as FacilityGrid

func current_cell() -> Vector2i:
	return grid().world_to_cell(global_position) if grid() != null else Vector2i.ZERO

func set_home_cell(c: Vector2i) -> void:
	home_cell = c

func _on_noise(pos: Vector3, loudness: float, source: Node, _tags: Array) -> void:
	if source == self or grid() == null:
		return
	var effective := grid().effective_loudness(loudness, pos, global_position)
	if effective < hearing_threshold:
		return
	if effective >= last_heard_loudness or _time - last_heard_at > 4.0:
		last_heard_position = pos
		last_heard_loudness = effective
		last_heard_at = _time
		_on_heard(pos, effective)

func _on_heard(_pos: Vector3, _loudness: float) -> void:
	pass

func _on_gaze_entered(target: Node3D) -> void:
	if target != self:
		return
	if not witnessed:
		witnessed = true
		EventBus.scp_witnessed.emit(designation)
	_on_first_observed()

func _on_first_observed() -> void:
	pass

## Max observation strength across every living observer — a guard staring
## at 173 holds it for you too (PLAN §20.4).
func total_observation() -> float:
	var strength := 0.0
	for observer in get_tree().get_nodes_in_group(&"gaze_observers"):
		if observer.has_method("observation_strength"):
			strength = maxf(strength, observer.observation_strength(self))
	return strength

## Collision bodies the gaze occlusion ray must ignore (self-occlusion).
func get_occlusion_exclude_rids() -> Array[RID]:
	var out: Array[RID] = []
	for child in get_children():
		var body := child as CollisionObject3D
		if body != null:
			out.append(body.get_rid())
	return out

func serialize_state() -> Dictionary:
	return {
		"pos": [global_position.x, global_position.y, global_position.z],
		"witnessed": witnessed,
	}

func deserialize_state(d: Dictionary) -> void:
	var p: Array = d.get("pos", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
	witnessed = bool(d.get("witnessed", false))
