## Seeded deterministic randomness (PLAN.md §5.5).
## Every run is defined by a seed. Never call randi()/randf() directly —
## always RNG.stream(&"name"). Independent stream per subsystem, so adding a
## loot roll does not shift the layout generation sequence.
extends Node

var _master_seed: int = 0
var _streams: Dictionary = {} # StringName -> RandomNumberGenerator

func set_master_seed(s: int) -> void:
	_master_seed = s
	_streams.clear()

func master_seed() -> int:
	return _master_seed

func stream(stream_name: StringName) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var r := RandomNumberGenerator.new()
		r.seed = hash(str(_master_seed) + "::" + str(stream_name))
		_streams[stream_name] = r
	return _streams[stream_name]

## Human-shareable seed code, shown on the death screen (PLAN §20.13).
## "Try seed 8F2A-91C3, I lasted 40 minutes."
static func seed_to_code(s: int) -> String:
	var u := s & 0xFFFFFFFF
	var hex := "%08X" % u
	return hex.substr(0, 4) + "-" + hex.substr(4, 4)

## Parses a seed code ("8F2A-91C3") or a plain integer string. Returns -1 if invalid.
static func code_to_seed(code: String) -> int:
	var c := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if c.is_empty():
		return -1
	if c.is_valid_int():
		return int(c)
	if c.length() == 8 and c.is_valid_hex_number():
		return ("0x" + c).hex_to_int()
	return -1
