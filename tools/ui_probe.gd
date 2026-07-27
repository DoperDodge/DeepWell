## Headless UI geometry probe:
##   godot --headless --path . -- --uiprobe
## Guards against the v0.5.0 field bug where top-level Controls under the
## CanvasLayer laid out against a zero-sized parent, putting the whole main
## menu off-screen. Asserts every named UI element actually lands inside
## the viewport at two different window sizes.
extends Node

var _failures: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("UIPROBE FAIL: " + msg)

func _ready() -> void:
	await get_tree().process_frame
	await _run()

func _run() -> void:
	var main := get_parent()
	main._show_menu()
	await _frames(4)
	_probe_menu("initial size")

	# Simulate a resize (maximize / user drag) — layout must follow.
	get_tree().root.size = Vector2i(1920, 1080)
	await _frames(4)
	_probe_menu("after resize to 1920x1080")

	# In-run overlays: HUD and a modal must also land on-screen.
	GameState.occupation = &"unassigned"
	main._start_run(998877, true, false)
	await _frames(6)
	var hud: Control = null
	for c in get_tree().root.find_children("*", "HUD", true, false):
		hud = c
	_check(hud != null, "HUD not found in run")
	if hud != null:
		_check(hud.size.x > 100 and hud.size.y > 100, "HUD has degenerate size %s" % hud.size)
	var ui := get_tree().get_first_node_in_group(&"game_ui")
	_check(ui != null, "game_ui missing")
	if ui != null:
		ui.open_container(_any_container())
		await _frames(3)
		var panel: Control = ui._modal_root
		_check(panel != null, "modal panel missing")
		if panel != null:
			_check_inside("inventory modal", panel)
		ui._close()

	if _failures.is_empty():
		print("UIPROBE OK — all UI geometry inside the viewport")
		get_tree().quit(0)
	else:
		print("UIPROBE FAILED — %d problem(s)" % _failures.size())
		get_tree().quit(1)

func _probe_menu(context: String) -> void:
	var menu: Control = null
	for c in get_tree().root.find_children("*", "MainMenu", true, false):
		menu = c
	_check(menu != null, "MainMenu not found (%s)" % context)
	if menu == null:
		return
	var vp := menu.get_viewport_rect().size
	_check(menu.size.x >= vp.x * 0.95 and menu.size.y >= vp.y * 0.95,
		"MainMenu not full-viewport (%s): size %s vs viewport %s" % [context, menu.size, vp])
	# The menu column (holds the title) must be fully on-screen.
	for label in menu.find_children("*", "Label", true, false):
		if (label as Label).text == "PROJECT DEEPWELL":
			_check_inside("title label (%s)" % context, label)
	var found_button := false
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("BEGIN"):
			found_button = true
			_check_inside("intake button (%s)" % context, b)
	_check(found_button, "intake button missing (%s)" % context)

func _check_inside(what: String, c: Control) -> void:
	var vp := c.get_viewport_rect().size
	var rect := c.get_global_rect()
	var inside := rect.position.x >= -1.0 and rect.position.y >= -1.0 \
		and rect.end.x <= vp.x + 1.0 and rect.end.y <= vp.y + 1.0 \
		and rect.size.x > 4.0 and rect.size.y > 4.0
	_check(inside, "%s off-screen or degenerate: rect %s, viewport %s" % [what, rect, vp])

func _any_container() -> Node:
	for c in get_tree().root.find_children("*", "WorldContainer", true, false):
		return c
	return null

func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame
