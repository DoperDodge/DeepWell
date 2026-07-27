## Survival needs (PLAN §10.3). All 0-100; high is bad. Ticked at 1 Hz via
## TimeManager — never per-frame. Rates are per in-game hour (§23) and scale
## with exertion; sprinting through the dark makes you hungry, thirsty, loud.
class_name NeedsComponent
extends Node

const RATES_PER_HOUR := {
	&"hunger": 1.4,
	&"thirst": 2.1,
	&"fatigue": 4.2,
	&"boredom": 3.0,
}

var values: Dictionary = {
	&"hunger": 30.0,   # Class-D start malnourished (PLAN §10.4)
	&"thirst": 25.0,
	&"fatigue": 15.0,
	&"boredom": 0.0,
	&"unhappiness": 10.0,
	&"stress": 5.0,
	&"panic": 0.0,
}

## Set by movement each frame: 1.0 idle/walk, up to 2.5 sprinting.
var exertion: float = 1.0

func _ready() -> void:
	TimeManager.register_tick(_tick, 1.0)

func get_value(id: StringName) -> float:
	return values.get(id, 0.0)

func adjust(id: StringName, delta: float) -> void:
	if delta == 0.0 or not values.has(id):
		return
	values[id] = clampf(values[id] + delta, 0.0, 100.0)
	EventBus.need_changed.emit(id, values[id])

func _tick() -> void:
	var per_second := 1.0 / TimeManager.GAME_HOUR_REAL_SECONDS
	var mult: float = GameState.sandbox.get("needs_rate", 1.0)
	for id in RATES_PER_HOUR:
		var rate: float = RATES_PER_HOUR[id] * per_second * mult
		if id == &"hunger" or id == &"thirst":
			rate *= exertion
		if id == &"hunger" and GameState.has_trait(&"hearty_appetite"):
			rate *= 1.35
		adjust(id, rate)
	# Panic decays on its own; stress decays only when panic is low.
	adjust(&"panic", -0.35)
	if values[&"panic"] < 20.0:
		adjust(&"stress", -0.08)
	# High needs feed unhappiness (PLAN §10.1 moodle interplay).
	if values[&"hunger"] > 70.0 or values[&"fatigue"] > 80.0 or values[&"boredom"] > 85.0:
		adjust(&"unhappiness", 0.06)
	else:
		adjust(&"unhappiness", -0.02)

func spike_panic(amount: float) -> void:
	adjust(&"panic", amount)
	adjust(&"stress", amount * 0.3)

func serialize() -> Dictionary:
	var out := {}
	for k in values:
		out[str(k)] = values[k]
	out["exertion"] = exertion
	return out

func deserialize(d: Dictionary) -> void:
	for k in values.keys():
		if d.has(str(k)):
			values[k] = float(d[str(k)])
