## Sanity (PLAN §10, §13.6): drains in darkness and in the presence of the
## anomalous; restores in light and through small mercies. Low sanity turns
## the presentation against you — whispers, heartbeat, screen distortion —
## without ever lying about game state (that's the cognitohazard track).
class_name SanitySystem
extends Node

var sanity: float = 100.0

var _whisper_cooldown: float = 0.0
var _heartbeat_cooldown: float = 0.0

func _ready() -> void:
	TimeManager.register_tick(_tick, 1.0)

func adjust(delta: float) -> void:
	if delta == 0.0:
		return
	var old := sanity
	sanity = clampf(sanity + delta, 0.0, 100.0)
	if absf(sanity - old) > 0.01:
		EventBus.sanity_changed.emit(sanity, sanity - old)

func _tick() -> void:
	var player := get_parent() as Node3D
	if player == null or not player.is_inside_tree():
		return
	var light := LightProbe.sample_at(player.global_position + Vector3.UP * 1.2)
	if light < 0.06:
		adjust(-0.18) # darkness eats you
	elif light > 0.25 and sanity < 65.0:
		adjust(0.06)
	# Presentation-side dread, all diegetic:
	var rng := RNG.stream(&"sanity_fx")
	_whisper_cooldown -= 1.0
	_heartbeat_cooldown -= 1.0
	if sanity < 45.0 and _whisper_cooldown <= 0.0 and rng.randf() < 0.06:
		_whisper_cooldown = rng.randf_range(20.0, 45.0)
		var offset := Vector3(rng.randf_range(-4, 4), 1.5, rng.randf_range(-4, 4))
		AudioManager.play_3d(&"whisper", player.global_position + offset, -14.0)
	if sanity < 30.0 and _heartbeat_cooldown <= 0.0:
		_heartbeat_cooldown = lerpf(0.9, 2.2, sanity / 30.0)
		AudioManager.play_ui(&"heartbeat", lerpf(-6.0, -18.0, sanity / 30.0))

func serialize() -> Dictionary:
	return {"sanity": sanity}

func deserialize(d: Dictionary) -> void:
	sanity = float(d.get("sanity", 100.0))
