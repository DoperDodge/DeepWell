## Blinking (PLAN §9.2) — a real, uncomfortable mechanic. Involuntary blink
## every 4-8 s; hold RMB to suppress at the cost of blink pressure; the
## eventual forced blink is longer. Nothing about this appears on the HUD —
## the player learns it by dying.
class_name PlayerBlink
extends Node

const BLINK_INTERVAL_MIN := 4.0
const BLINK_INTERVAL_MAX := 8.0
const BLINK_DURATION := 0.15
const BLINK_FORCED_DURATION := 0.40
const PRESSURE_BUILD := 0.14      # per second while suppressing
const PRESSURE_MAX := 1.0

var is_blinking: bool = false
## 0 = eyes open, 1 = fully shut. HUD eyelid overlay reads this.
var closure: float = 0.0
var pressure: float = 0.0

var _next_blink: float = 0.0
var _blink_left: float = 0.0
var _blink_total: float = 0.15

func _ready() -> void:
	_schedule_next()

func _process(delta: float) -> void:
	var player := get_parent() as CharacterBody3D
	if player == null or player.dead:
		return
	if not GameState.sandbox.get("blinking_enabled", true):
		closure = 0.0
		is_blinking = false
		return

	if _blink_left > 0.0:
		_blink_left -= delta
		# Eyelid curve: fast close, brief hold, fast open.
		var t := 1.0 - _blink_left / _blink_total
		closure = clampf(sin(t * PI) * 1.8, 0.0, 1.0)
		is_blinking = closure > 0.55
		if _blink_left <= 0.0:
			closure = 0.0
			is_blinking = false
		return

	var suppressing := Input.is_action_pressed("hold_eyes")
	if Input.is_action_just_pressed("blink"):
		# Voluntary blink: blink on your own terms, reset the clock.
		_start_blink(BLINK_DURATION)
		return
	if suppressing:
		pressure = minf(pressure + PRESSURE_BUILD * delta * _fatigue_factor(), PRESSURE_MAX)
		if pressure >= PRESSURE_MAX:
			_start_blink(BLINK_FORCED_DURATION) # eyes slam shut, long
		return
	pressure = maxf(pressure - delta * 0.5, 0.0)
	_next_blink -= delta * _fatigue_factor()
	if _next_blink <= 0.0:
		_start_blink(BLINK_DURATION)

func _start_blink(duration: float) -> void:
	_blink_total = duration
	_blink_left = duration
	pressure = 0.0
	_schedule_next()
	EventBus.player_blinked.emit(duration)

func _schedule_next() -> void:
	_next_blink = RNG.stream(&"blink").randf_range(BLINK_INTERVAL_MIN, BLINK_INTERVAL_MAX)

## Exhaustion and terror make you blink faster. This is what kills you.
func _fatigue_factor() -> float:
	var player := get_parent()
	var factor := 1.0
	if player.needs.get_value(&"fatigue") > 70.0:
		factor += 0.4
	if player.needs.get_value(&"panic") > 60.0:
		factor += 0.35
	if player.sanity.sanity < 35.0:
		factor += 0.25
	return factor
