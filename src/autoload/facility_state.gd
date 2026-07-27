## Facility-wide state: door states, container contents, alarm level, power,
## breach registry — plus the PERSISTENT SITE FILE that survives your death
## (PLAN §16.3): corpses keep their gear, welded doors stay welded, and each
## new Class-D processed into the site gets the next designation number.
extends Node

const SITE_DIR := "user://sites"
const SITE_VERSION := 1

# --- Run-scoped registries (rebuilt from seed + diffs on load) ---
var door_states: Dictionary = {}        # door_id -> int (Door.DoorState)
var container_contents: Dictionary = {} # container_id -> Array[Dictionary] (item instances)
var opened_containers: Dictionary = {}  # container_id -> true (loot already rolled)
var removed_pickups: Dictionary = {}    # pickup_id -> true
var alarm_level: int = 0
var power_zones: Dictionary = {}        # zone StringName -> bool

# --- Site-scoped state (persists across deaths, keyed by seed) ---
var site_seed: int = 0
var d_class_counter: int = 9341
var corpses: Array = []       # [{floor:int, cell:[x,y], cause:String, designation:String, items:Array}]
var incident_log: Array = []  # dry Foundation prose describing the player's own actions
var breached: Array = []      # StringName designations
var site_deaths: int = 0

func begin_run(seed_value: int) -> void:
	door_states.clear()
	container_contents.clear()
	opened_containers.clear()
	removed_pickups.clear()
	alarm_level = 0
	power_zones.clear()
	if site_seed != seed_value:
		load_site(seed_value)

func set_alarm(level: int) -> void:
	if level != alarm_level:
		alarm_level = level
		EventBus.alarm_level_changed.emit(level)

func set_power(zone: StringName, powered: bool) -> void:
	power_zones[zone] = powered
	EventBus.power_state_changed.emit(zone, powered)

func is_powered(zone: StringName) -> bool:
	return power_zones.get(zone, true)

func log_incident(text: String) -> void:
	incident_log.append({"t": TimeManager.clock_string(), "text": text})
	EventBus.incident_logged.emit(text)

func register_breach(designation: StringName) -> void:
	if not breached.has(designation):
		breached.append(designation)
		EventBus.containment_breached.emit(designation)

# --- Death / corpse persistence (PLAN §16.3, §20.1) ---

func record_player_death(floor_index: int, cell: Vector2i, cause: String, items: Array) -> void:
	site_deaths += 1
	corpses.append({
		"floor": floor_index,
		"cell": [cell.x, cell.y],
		"cause": cause,
		"designation": GameState.designation,
		"items": items,
	})
	log_incident("Subject %s terminated. Cause: %s. Remains unrecovered." % [GameState.designation, cause])
	save_site()

func corpses_on_floor(floor_index: int) -> Array:
	return corpses.filter(func(c: Dictionary) -> bool: return int(c.floor) == floor_index)

func remove_corpse(corpse: Dictionary) -> void:
	corpses.erase(corpse)
	save_site()

func next_designation() -> String:
	var s := "D-%d" % d_class_counter
	d_class_counter += 1
	save_site()
	return s

# --- Site file IO ---

func reset_site(seed_value: int) -> void:
	site_seed = seed_value
	d_class_counter = 9341
	corpses = []
	incident_log = []
	breached = []
	site_deaths = 0
	save_site()

func _site_path(seed_value: int) -> String:
	return "%s/site_%s.json" % [SITE_DIR, RNG.seed_to_code(seed_value).replace("-", "")]

func load_site(seed_value: int) -> void:
	site_seed = seed_value
	var path := _site_path(seed_value)
	if not FileAccess.file_exists(path):
		reset_site(seed_value)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		reset_site(seed_value)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		reset_site(seed_value)
		return
	var d: Dictionary = parsed
	d_class_counter = int(d.get("d_class_counter", 9341))
	corpses = d.get("corpses", [])
	incident_log = d.get("incident_log", [])
	breached.assign(d.get("breached", []))
	site_deaths = int(d.get("site_deaths", 0))

func save_site() -> void:
	DirAccess.make_dir_recursive_absolute(SITE_DIR)
	var f := FileAccess.open(_site_path(site_seed), FileAccess.WRITE)
	if f == null:
		push_warning("FacilityState: cannot write site file")
		return
	f.store_string(JSON.stringify({
		"version": SITE_VERSION,
		"seed": site_seed,
		"d_class_counter": d_class_counter,
		"corpses": corpses,
		"incident_log": incident_log,
		"breached": breached,
		"site_deaths": site_deaths,
	}, "\t"))

# --- Run-state serialization for SaveManager ---

func serialize_run() -> Dictionary:
	return {
		"door_states": door_states,
		"container_contents": container_contents,
		"opened_containers": opened_containers,
		"removed_pickups": removed_pickups,
		"alarm_level": alarm_level,
		"power_zones": power_zones,
	}

func deserialize_run(d: Dictionary) -> void:
	door_states = d.get("door_states", {})
	container_contents = d.get("container_contents", {})
	opened_containers = d.get("opened_containers", {})
	removed_pickups = d.get("removed_pickups", {})
	alarm_level = int(d.get("alarm_level", 0))
	power_zones = d.get("power_zones", {})
