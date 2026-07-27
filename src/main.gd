## Entry point and scene flow: main menu -> run -> death/descend -> menu.
## Owns the world root; everything else communicates via EventBus.
extends Node

var _world: Node3D = null
var _ui_root: CanvasLayer = null
var _menu: Control = null

func _ready() -> void:
	_ui_root = CanvasLayer.new()
	_ui_root.name = "UIRoot"
	add_child(_ui_root)
	EventBus.restart_requested.connect(_on_restart_requested, CONNECT_DEFERRED)
	EventBus.menu_requested.connect(_show_menu, CONNECT_DEFERRED)
	EventBus.descend_requested.connect(_on_descend_requested, CONNECT_DEFERRED)
	var volume := Settings.master_volume()
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	var tools := {
		"--validate": "res://tools/validate_project.gd",
		"--smoke": "res://tools/smoke_test.gd",
		"--uiprobe": "res://tools/ui_probe.gd",
	}
	for flag in tools:
		if OS.get_cmdline_user_args().has(flag):
			_run_tool(flag, tools[flag])
			return
	_show_menu()

## Headless entry points. A tool script that fails to compile must abort the
## process — falling through to the menu leaves a headless CI job hanging
## with no output until its timeout.
func _run_tool(flag: String, path: String) -> void:
	var script: GDScript = load(path) as GDScript
	if script == null or not script.can_instantiate():
		printerr("FATAL: %s script failed to compile: %s" % [flag, path])
		get_tree().quit(1)
		return
	add_child(script.new())

func _on_restart_requested(keep_site: bool) -> void:
	_start_run(GameState.run_seed, keep_site, false)

## Stairwell used. Carry the player (minus position) down a floor, or roll
## the ending on the final floor. Descending is one-way — the only way out
## is down (PLAN §1).
func _on_descend_requested() -> void:
	var floor_def := load("res://data/floors/floor_%d.tres" % GameState.floor_index) as FloorDef
	if floor_def != null and floor_def.final_floor:
		SaveManager.delete_save()
		get_tree().call_group(&"game_ui", "show_ending")
		return
	var player_data: Dictionary = {}
	if GameState.player != null:
		player_data = GameState.player.serialize()
		player_data.erase("pos")
		player_data.erase("camera")
	var from_floor := GameState.floor_index
	GameState.floor_index += 1
	GameState.player = null
	EventBus.player_moved_floor.emit(from_floor, GameState.floor_index)
	_build_world(false, player_data)
	SaveManager.save_run() # descending is the checkpoint (PLAN §16.2)

func _show_menu() -> void:
	_clear_world()
	var menu_script: GDScript = load("res://src/ui/main_menu.gd")
	_menu = menu_script.new()
	_menu.start_requested.connect(_on_start_requested)
	_menu.resume_requested.connect(_on_resume_requested)
	_ui_root.add_child(_menu)

func _on_start_requested(seed_value: int, keep_site: bool) -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	_start_run(seed_value, keep_site, false)

func _on_resume_requested() -> void:
	var data := SaveManager.read_save()
	if data.is_empty():
		return
	if _menu != null:
		_menu.queue_free()
		_menu = null
	SaveManager.stage_loaded_state(data)
	_start_run(int(data.get("seed", 0)), true, true)

func _start_run(seed_value: int, keep_site: bool, resume: bool) -> void:
	GameState.start_new_run(seed_value, keep_site, resume)
	if resume:
		GameState.floor_index = int(SaveManager.read_save().get("floor", GameState.floor_index))
	_build_world(resume)

func _build_world(resume: bool, carried_player_state: Dictionary = {}) -> void:
	_clear_world()
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)

	var cutaway_script: GDScript = load("res://src/facility/wall_cutaway.gd")
	_world.add_child(cutaway_script.new())

	var generator_script: GDScript = load("res://src/facility/floor_generator.gd")
	var generator: Node = generator_script.new()
	_world.add_child(generator)
	var result: Dictionary = generator.generate(GameState.floor_index)

	var player_scene: GDScript = load("res://src/player/player.gd")
	var player: CharacterBody3D = player_scene.new()
	_world.add_child(player)
	player.global_position = result.get("spawn_position", Vector3(0, 1.0, 0))
	GameState.player = player

	var hud_script: GDScript = load("res://src/ui/hud.gd")
	var hud: Control = hud_script.new()
	_ui_root.add_child(hud)

	var game_ui_script: GDScript = load("res://src/ui/game_ui.gd")
	var game_ui: Control = game_ui_script.new()
	_ui_root.add_child(game_ui)

	if resume:
		SaveManager.apply_staged_state()
	elif not carried_player_state.is_empty():
		player.deserialize(carried_player_state)
	EventBus.player_spawned.emit(player)
	SaveManager.save_run() # a run always has a resumable save from second one

func _clear_world() -> void:
	AudioManager.stop_all_ambience()
	if _world != null:
		_world.queue_free()
		_world = null
	for child in _ui_root.get_children():
		if child != _menu:
			child.queue_free()
