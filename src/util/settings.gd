## User settings persisted to user://settings.cfg (options menu backend).
## Static access — not an autoload; nothing here is per-run state.
class_name Settings
extends RefCounted

const PATH := "user://settings.cfg"

static var _cfg: ConfigFile = null

static func _ensure() -> void:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH) # missing file is fine — defaults apply

static func get_value(key: String, default_value: Variant) -> Variant:
	_ensure()
	return _cfg.get_value("main", key, default_value)

static func set_value(key: String, value: Variant) -> void:
	_ensure()
	_cfg.set_value("main", key, value)
	_cfg.save(PATH)

# Convenience accessors with the project defaults.
static func camera_zoom() -> float: return get_value("camera_zoom", 13.0)
static func master_volume() -> float: return get_value("master_volume", 1.0)
static func film_grain() -> bool: return get_value("film_grain", true)
static func show_subtitles() -> bool: return get_value("subtitles", true)
