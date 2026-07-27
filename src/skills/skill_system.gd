## Skills-lite (PLAN §10.7, scoped): four skills that train by doing and
## matter every minute. Level = floor(sqrt(xp / 40)), capped at 10.
##  - lightfooted: crouched steps  -> quieter footsteps
##  - fitness:     sprinting       -> larger stamina pool
##  - first_aid:   treatments      -> stronger treatment effects
##  - scavenging:  searches        -> faster container searches
class_name SkillSystem
extends Node

const SKILL_IDS: Array[StringName] = [&"lightfooted", &"fitness", &"first_aid", &"scavenging"]
const XP_PER_LEVEL_SQ := 40.0

var xp: Dictionary = {} # StringName -> float

func _ready() -> void:
	for id in SKILL_IDS:
		if not xp.has(id):
			xp[id] = 0.0
	_apply_occupation_seed()

## Occupations arrive trained (PLAN §10.8).
func _apply_occupation_seed() -> void:
	match GameState.occupation:
		&"medic":
			xp[&"first_aid"] = maxf(xp[&"first_aid"], _xp_for_level(3))
		&"burglar":
			xp[&"lightfooted"] = maxf(xp[&"lightfooted"], _xp_for_level(2))
			xp[&"scavenging"] = maxf(xp[&"scavenging"], _xp_for_level(2))
		&"athlete":
			xp[&"fitness"] = maxf(xp[&"fitness"], _xp_for_level(4))

func _xp_for_level(lv: int) -> float:
	return float(lv * lv) * XP_PER_LEVEL_SQ

func level(id: StringName) -> int:
	return mini(int(sqrt(float(xp.get(id, 0.0)) / XP_PER_LEVEL_SQ)), 10)

func add_xp(id: StringName, amount: float) -> void:
	if not xp.has(id):
		return
	var before := level(id)
	xp[id] = float(xp[id]) + amount
	EventBus.skill_xp_gained.emit(id, amount)
	var after := level(id)
	if after > before:
		EventBus.skill_level_up.emit(id, after)
		EventBus.toast.emit("%s improved to %d." % [str(id).capitalize(), after])

func serialize() -> Dictionary:
	var out := {}
	for k in xp:
		out[str(k)] = xp[k]
	return out

func deserialize(d: Dictionary) -> void:
	for k in d:
		xp[StringName(k)] = float(d[k])
