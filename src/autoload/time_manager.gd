## In-game clock and staggered tick scheduling (PLAN §5.1, §18.3).
## Survival/perception systems must NOT run every frame — they register here
## and are ticked on offset schedules so their work never lands on one frame.
extends Node

## 1 in-game hour = 90 real seconds (PLAN §23).
const GAME_HOUR_REAL_SECONDS := 90.0
## The breach happened at 03:47. You wake shortly after.
const START_HOUR := 3.0 + 47.0 / 60.0

signal game_hour_passed(hour: int)

var game_hours: float = START_HOUR
var simulation_running: bool = false

var _ticks: Array[Dictionary] = [] # {cb: Callable, interval: float, next: float}
var _elapsed: float = 0.0
var _last_whole_hour: int = int(START_HOUR)

func _ready() -> void:
	EventBus.run_started.connect(_on_run_started)
	EventBus.run_ended.connect(func(_o: StringName) -> void: simulation_running = false)

func _process(delta: float) -> void:
	if not simulation_running or get_tree().paused:
		return
	_elapsed += delta
	game_hours += delta / GAME_HOUR_REAL_SECONDS
	if int(game_hours) != _last_whole_hour:
		_last_whole_hour = int(game_hours)
		game_hour_passed.emit(_last_whole_hour)
	for t in _ticks:
		if _elapsed >= t.next:
			t.next += t.interval
			if _elapsed >= t.next: # missed several ticks (lag spike) — resync, don't burst
				t.next = _elapsed + t.interval
			var cb: Callable = t.cb
			if cb.is_valid():
				cb.call()

## Register a periodic callback. Stagger offset is derived from the hash of
## the callable so registrants naturally spread across frames.
func register_tick(cb: Callable, interval: float) -> void:
	var stagger := fmod(float(hash(cb) % 1000) / 1000.0, 1.0) * interval
	_ticks.append({"cb": cb, "interval": interval, "next": _elapsed + stagger + 0.05})

func unregister_tick(cb: Callable) -> void:
	for i in range(_ticks.size() - 1, -1, -1):
		if _ticks[i].cb == cb:
			_ticks.remove_at(i)

func clock_string() -> String:
	var h := int(game_hours) % 24
	var m := int(fmod(game_hours, 1.0) * 60.0)
	return "%02d:%02d" % [h, m]

func hours_survived() -> float:
	return game_hours - START_HOUR

func _on_run_started(_seed_value: int) -> void:
	game_hours = START_HOUR
	_last_whole_hour = int(START_HOUR)
	_elapsed = 0.0
	_ticks.clear()
	simulation_running = true

func serialize() -> Dictionary:
	return {"game_hours": game_hours}

func deserialize(d: Dictionary) -> void:
	game_hours = d.get("game_hours", START_HOUR)
	_last_whole_hour = int(game_hours)
