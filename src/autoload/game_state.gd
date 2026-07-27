## Current-run state: seed, floor, player reference, clearance, sandbox
## settings, and run telemetry for the termination report (PLAN §5.1, §16.3).
## Pure data — scene flow lives in main.gd, persistence in SaveManager.
extends Node

const DEFAULT_FLOOR := 3 # vertical slice starts in Light Containment

var run_active: bool = false
var run_seed: int = 0
var floor_index: int = DEFAULT_FLOOR
var player: Node3D = null
## FacilityGrid of the current floor — shared spatial data (pathfinding,
## noise propagation, door topology). Set by the floor generator.
var grid: RefCounted = null
var designation: String = "D-9341"

## Highest keycard clearance currently held (0-5). Drives door access AND
## document declassification (PLAN §8.1 — same axis by design).
var clearance: int = 0

## Sandbox settings (PLAN §10.12). Serialized with saves.
var sandbox: Dictionary = {
	"needs_rate": 1.0,          # hunger/thirst/fatigue multiplier
	"anomaly_aggression": 1.0,  # SCP stalk pressure multiplier
	"loot_abundance": 1.0,
	"blinking_enabled": true,
	"ironman": true,
	"director_enabled": true,
}

## Run telemetry — feeds the Foundation Termination Report (PLAN §16.3).
var stats: Dictionary = {}

## Collected documents: doc_id -> clearance held when last read. Drives the
## "new information available" marker after finding a better keycard (§8.1).
var journal: Dictionary = {}

## True while a modal UI screen is open — gameplay input is suspended but
## the world keeps running (searching a bag mid-corridor is a choice).
var ui_blocking: bool = false

func _ready() -> void:
	_reset_stats()
	EventBus.document_read.connect(func(_id: StringName) -> void: stats.documents_read += 1)
	EventBus.scp_witnessed.connect(_on_scp_witnessed)
	EventBus.keycard_acquired.connect(_on_keycard)

## keep_site=true continues an existing site (corpses persist, designation
## counter advances). resume=true restores a saved run: no new designation is
## burned and run state is applied afterwards by SaveManager.
func start_new_run(seed_value: int, keep_site: bool, resume: bool = false) -> void:
	run_seed = seed_value
	run_active = true
	floor_index = DEFAULT_FLOOR
	clearance = 0
	journal = {}
	ui_blocking = false
	RNG.set_master_seed(seed_value)
	_reset_stats()
	if not keep_site and not resume:
		FacilityState.reset_site(seed_value)
	FacilityState.begin_run(seed_value)
	if not resume:
		designation = FacilityState.next_designation()
	EventBus.run_started.emit(seed_value)

func end_run(outcome: StringName) -> void:
	run_active = false
	player = null
	EventBus.run_ended.emit(outcome)

func seed_code() -> String:
	return RNG.seed_to_code(run_seed)

func grant_clearance(level: int) -> void:
	if level > clearance:
		clearance = level
		EventBus.clearance_changed.emit(level)

func _reset_stats() -> void:
	stats = {
		"documents_read": 0,
		"anomalies_witnessed": [],
		"kills_caused": 0,
		"items_used": 0,
		"distance_walked_m": 0.0,
		"closest_173_m": 999.0,
		"time_started_hours": 0.0,
	}

func _on_scp_witnessed(designation_id: StringName) -> void:
	var seen: Array = stats.anomalies_witnessed
	if not seen.has(designation_id):
		seen.append(designation_id)

func _on_keycard(level: int) -> void:
	grant_clearance(level)
