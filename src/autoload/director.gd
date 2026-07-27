## Dynamic pacing (PLAN §12.4), modeled on L4D's AI Director.
## Tracks a tension value; enforces rest beats after scares (sustained terror
## becomes numbness); escalates when the player camps. Anomalies query
## stalk_pressure() to decide how aggressively to seek the player.
extends Node

var tension: float = 0.0          # 0..1
var enabled: bool = true

var _rest_until: float = 0.0      # while _now < this, anomalies are leashed away
var _now: float = 0.0
var _camp_position: Vector3 = Vector3.ZERO
var _camp_time: float = 0.0
var _camp_warned: bool = false

func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	TimeManager.register_tick(_slow_tick, 2.0) # cheap; re-registered per run below

func _process(delta: float) -> void:
	if not GameState.run_active or get_tree().paused:
		return
	_now += delta
	tension = maxf(tension - delta * 0.01, 0.0) # slow decay toward calm

## Anomalies call this each think-tick. 0 = leave the player alone (rest
## beat), 1 = normal wandering interest, >1 = actively converge on player.
func stalk_pressure() -> float:
	if not enabled:
		return 1.0
	if _now < _rest_until:
		return 0.0
	var aggression: float = GameState.sandbox.get("anomaly_aggression", 1.0)
	if _camp_time > 600.0: # 10 min camping: the facility does not wait (§12.4)
		return 2.5 * aggression
	return (0.6 + tension * 0.8) * aggression

## Report a scare (near-miss, chase, kill attempt). intensity 0..1.
## High-intensity scares buy the player a guaranteed 60-120 s of quiet.
func report_scare(intensity: float) -> void:
	tension = clampf(tension + intensity * 0.5, 0.0, 1.0)
	if intensity >= 0.6:
		var rest := RNG.stream(&"director").randf_range(60.0, 120.0)
		_rest_until = _now + rest

func _slow_tick() -> void:
	if not GameState.run_active or GameState.player == null:
		return
	enabled = GameState.sandbox.get("director_enabled", true)
	var p := GameState.player as Node3D
	if p == null or not p.is_inside_tree():
		return
	# Camping detection: standing within 6 m of the same spot.
	if p.global_position.distance_to(_camp_position) > 6.0:
		_camp_position = p.global_position
		_camp_time = 0.0
		_camp_warned = false
	else:
		_camp_time += 2.0
	if _camp_time > 480.0 and not _camp_warned:
		_camp_warned = true
		EventBus.pa_announcement.emit("Attention: motion tracking in your sector has flagged loitering. Site security protocols remain in effect.")
	# Tension inputs: darkness and low health raise it slowly.
	var light := LightProbe.sample_at(p.global_position)
	if light < 0.1:
		tension = clampf(tension + 0.01, 0.0, 1.0)

func _on_run_started(_seed_value: int) -> void:
	tension = 0.0
	_rest_until = 0.0
	_now = 0.0
	_camp_time = 0.0
	_camp_warned = false
	TimeManager.register_tick(_slow_tick, 2.0)
