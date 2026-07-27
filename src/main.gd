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
	_show_menu()

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
	_build_world(resume)

func _build_world(resume: bool) -> void:
	_clear_world()
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)

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
	EventBus.player_spawned.emit(player)
	_connect_run_end()

func _connect_run_end() -> void:
	if not EventBus.run_ended.is_connected(_on_run_ended):
		EventBus.run_ended.connect(_on_run_ended)

func _on_run_ended(outcome: StringName) -> void:
	# Death/descend screens are pushed by game_ui; when they finish they emit
	# ui_screen_changed(&"menu") which routes here via this deferred cleanup.
	if outcome == &"quit":
		_show_menu.call_deferred()

func return_to_menu() -> void:
	_show_menu()

func _clear_world() -> void:
	AudioManager.stop_all_ambience()
	if _world != null:
		_world.queue_free()
		_world = null
	for child in _ui_root.get_children():
		if child != _menu:
			child.queue_free()
