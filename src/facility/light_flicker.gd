## Broken fluorescent flicker — irregular, non-sine (PLAN §13.2: "regular
## flicker reads as fake"). Deterministic per fixture from its seed.
class_name LightFlicker
extends OmniLight3D

var base_energy: float = 1.0
var flicker_seed: int = 0

var _t: float = 0.0
var _state: float = 1.0
var _next_event: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = flicker_seed
	base_energy = light_energy
	_next_event = _rng.randf_range(0.05, 2.0)

func _process(delta: float) -> void:
	_t += delta
	if _t >= _next_event:
		_t = 0.0
		if _state > 0.5:
			# Drop out: short stutter or a longer dark gap.
			_state = _rng.randf_range(0.0, 0.25)
			_next_event = _rng.randf_range(0.03, 0.4) if _rng.randf() < 0.75 else _rng.randf_range(0.8, 2.2)
		else:
			_state = _rng.randf_range(0.75, 1.0)
			_next_event = _rng.randf_range(0.2, 3.5)
	light_energy = base_energy * lerpf(light_energy / maxf(base_energy, 0.01), _state, 0.5)
	# LightProbe reads visibility, not energy — go truly dark when out.
	visible = _state > 0.1 or light_energy > 0.1
