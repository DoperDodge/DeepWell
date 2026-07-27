## Main menu: continue, new run (with shareable seed entry, PLAN §20.13),
## credits & licensing (a CC BY-SA requirement, PLAN §2.2), quit.
class_name MainMenu
extends Control

signal start_requested(seed_value: int, keep_site: bool)
signal resume_requested

var _seed_edit: LineEdit
var _credits_panel: PanelContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.017, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.custom_minimum_size = Vector2(460, 0)
	column.position -= Vector2(230, 220)
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var title := Label.new()
	title.text = "PROJECT DEEPWELL"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "SITE-104  ·  DEEP STORAGE VERTICAL\nCONTAINMENT STATUS: [DATA EXPUNGED]"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.45, 0.15))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	column.add_child(_spacer(24))

	if SaveManager.has_save():
		var resume := _button("CONTINUE — an active D-Class is in the site")
		resume.pressed.connect(func() -> void: resume_requested.emit())
		column.add_child(resume)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "seed code (blank = random)"
	_seed_edit.custom_minimum_size = Vector2(300, 0)
	seed_row.add_child(_seed_edit)
	var start := _button("BEGIN INTAKE")
	start.pressed.connect(_on_start)
	seed_row.add_child(start)
	column.add_child(seed_row)

	var hint := Label.new()
	hint.text = "Reusing a seed returns you to the same site: your corpses,\nyour welded doors, and whatever you set loose are still there."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.52, 0.55))
	column.add_child(hint)

	column.add_child(_spacer(16))

	var credits := _button("CREDITS && LICENSING (CC BY-SA 3.0)")
	credits.pressed.connect(_show_credits)
	column.add_child(credits)

	var quit := _button("QUIT")
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)

	var controls := Label.new()
	controls.text = "WASD move · SHIFT sprint · C crouch · E interact · F flashlight · TAB inventory\nJ journal · Q/R lean · B blink now · hold RMB to keep your eyes open · F3 debug"
	controls.add_theme_font_size_override("font_size", 12)
	controls.add_theme_color_override("font_color", Color(0.45, 0.47, 0.5))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	controls.position += Vector2(-330, -60)
	add_child(controls)

func _on_start() -> void:
	var seed_value := RNG.code_to_seed(_seed_edit.text)
	if seed_value < 0:
		seed_value = int(Time.get_unix_time_from_system()) ^ (Time.get_ticks_usec() << 8)
		seed_value = absi(seed_value) & 0xFFFFFFFF
	start_requested.emit(seed_value, true)

func _show_credits() -> void:
	if _credits_panel != null:
		_credits_panel.queue_free()
		_credits_panel = null
		return
	_credits_panel = PanelContainer.new()
	_credits_panel.set_anchors_preset(Control.PRESET_CENTER)
	_credits_panel.custom_minimum_size = Vector2(720, 480)
	_credits_panel.position -= Vector2(360, 240)
	add_child(_credits_panel)
	var scroll := ScrollContainer.new()
	_credits_panel.add_child(scroll)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.custom_minimum_size = Vector2(690, 0)
	text.text = _credits_text()
	scroll.add_child(text)

func _credits_text() -> String:
	var lines: Array[String] = []
	lines.append("[b]PROJECT DEEPWELL[/b]\n")
	lines.append("Content relating to the SCP Foundation, including the SCP Foundation logo, is licensed under Creative Commons Attribution-ShareAlike 3.0 (https://creativecommons.org/licenses/by-sa/3.0/) and all concepts originate from https://scpwiki.com and its authors.\n")
	lines.append("PROJECT DEEPWELL, being derived from this content, is hereby also released under Creative Commons Attribution-ShareAlike 3.0.\n")
	lines.append("[b]SCP article credits[/b]")
	var f := FileAccess.open("res://data/attribution.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_ARRAY:
			for entry: Dictionary in parsed:
				lines.append("  %s — %s — by %s" % [entry.get("designation", "?"), entry.get("url", ""), entry.get("authors", "see page history")])
	lines.append("\nAll visual designs in this game are original; no SCP Wiki images were used or referenced (see docs/ATTRIBUTION.md — including the SCP-173 / Izumi Kato notice).")
	lines.append("\n[b]Engine[/b]\nGodot Engine © 2007–present Juan Linietsky, Ariel Manzur and contributors — MIT License — godotengine.org")
	lines.append("\nAll geometry and audio in this build are procedurally generated; the repository contains no third-party assets.")
	lines.append("\n[i]Click CREDITS again to close.[/i]")
	return "\n".join(lines)

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 16)
	return b

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
