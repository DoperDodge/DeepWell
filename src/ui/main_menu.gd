## Main menu: continue, new run (with shareable seed entry, PLAN §20.13),
## credits & licensing (a CC BY-SA requirement, PLAN §2.2), quit.
class_name MainMenu
extends Control

signal start_requested(seed_value: int, keep_site: bool)
signal resume_requested

const OCCUPATIONS := [
	{"id": &"unassigned", "name": "Class-D (Unassigned)", "desc": "No skills, no gear, two extra trait points. The default hard mode.", "points": 2},
	{"id": &"medic", "name": "Former Medic", "desc": "First Aid 3. Treatments 30% stronger. Starts with bandage + disinfectant.", "points": 0},
	{"id": &"burglar", "name": "Former Burglar", "desc": "Lightfooted 2, Scavenging 2. 40% quieter, 40% faster searches. Starts with a crowbar.", "points": 0},
	{"id": &"athlete", "name": "Former Athlete", "desc": "Fitness 4. Bigger stamina pool, faster sprint.", "points": 0},
	{"id": &"electrician", "name": "Former Electrician", "desc": "Can hotwire powered-down doors barehanded. Starts with wire.", "points": 0},
	{"id": &"chemist", "name": "Former Chemist", "desc": "Iron stomach; the Pestilence advances 25% slower in you. Starts with disinfectant.", "points": 0},
]
const TRAITS := [
	{"id": &"steady_hands", "name": "Steady Hands", "desc": "Blink 45% less often. You know exactly why that matters.", "cost": 2},
	{"id": &"cat_eyes", "name": "Cat Eyes", "desc": "Darkness drains sanity half as fast.", "cost": 2},
	{"id": &"light_step", "name": "Light Step", "desc": "Footsteps 25% quieter.", "cost": 2},
	{"id": &"iron_gut", "name": "Iron Gut", "desc": "Spoiled food cannot sicken you.", "cost": 1},
	{"id": &"twitchy", "name": "Twitchy", "desc": "Blink 35% more often. The Sculpture thanks you.", "cost": -2},
	{"id": &"nyctophobic", "name": "Nyctophobic", "desc": "Darkness eats your sanity at double rate.", "cost": -2},
	{"id": &"asthmatic", "name": "Asthmatic", "desc": "Long sprints end in loud, involuntary wheezing.", "cost": -2},
	{"id": &"hearty_appetite", "name": "Hearty Appetite", "desc": "Hunger climbs 35% faster.", "cost": -1},
	{"id": &"smoker", "name": "Smoker", "desc": "Without a cigarette every two hours, you fray.", "cost": -1},
]

var _seed_edit: LineEdit
var _credits_panel: PanelContainer
var _credits_overlay: Control
var _intake_panel: PanelContainer
var _intake_overlay: Control
var _occupation_index: int = 0
var _trait_checks: Dictionary = {}
var _points_label: Label

func _ready() -> void:
	UILayout.fullscreen(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.017, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	UILayout.fullscreen(bg)

	var wrap := UILayout.center_overlay(self)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(500, 0)
	column.add_theme_constant_override("separation", 10)
	(wrap.center as Control).add_child(column)

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

	var start := _button("BEGIN INTAKE")
	start.pressed.connect(_open_intake)
	column.add_child(start)

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

	# Controls footer: bottom-centered by a container, not by arithmetic.
	var footer := VBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(footer)
	UILayout.fullscreen(footer)
	var controls := Label.new()
	controls.text = "WASD move · SHIFT sprint · C crouch · E interact · F flashlight · TAB inventory\nJ journal · Q/R lean · B blink now · hold RMB to keep your eyes open · F3 debug"
	controls.add_theme_font_size_override("font_size", 12)
	controls.add_theme_color_override("font_color", Color(0.45, 0.47, 0.5))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	footer.add_child(controls)
	var footer_pad := Control.new()
	footer_pad.custom_minimum_size = Vector2(0, 26)
	footer.add_child(footer_pad)

## Intake: occupation, traits (point-buy, PLAN §10.8), sandbox, seed.
func _open_intake() -> void:
	if _intake_overlay != null:
		_intake_overlay.queue_free()
	var wrap := UILayout.center_overlay(self, true)
	_intake_overlay = wrap.root
	_intake_panel = PanelContainer.new()
	(wrap.center as Control).add_child(_intake_panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(780, 0)
	box.add_theme_constant_override("separation", 6)
	_intake_panel.add_child(box)

	var title := Label.new()
	title.text = "D-CLASS INTAKE PROCESSING — FORM 104-D"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	box.add_child(title)

	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 16)
	box.add_child(panes)

	# Occupation column.
	var occ_col := VBoxContainer.new()
	panes.add_child(occ_col)
	var occ_label := Label.new()
	occ_label.text = "PRIOR OCCUPATION"
	occ_label.add_theme_font_size_override("font_size", 13)
	occ_col.add_child(occ_label)
	var occ_list := ItemList.new()
	occ_list.custom_minimum_size = Vector2(300, 168)
	for occ in OCCUPATIONS:
		occ_list.add_item(occ.name)
	occ_list.select(0)
	var occ_desc := Label.new()
	occ_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	occ_desc.custom_minimum_size = Vector2(300, 70)
	occ_desc.add_theme_font_size_override("font_size", 12)
	occ_desc.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
	occ_desc.text = OCCUPATIONS[0].desc
	occ_list.item_selected.connect(func(i: int) -> void:
		_occupation_index = i
		occ_desc.text = OCCUPATIONS[i].desc
		_update_points())
	occ_col.add_child(occ_list)
	occ_col.add_child(occ_desc)

	# Traits column.
	var trait_col := VBoxContainer.new()
	panes.add_child(trait_col)
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 13)
	trait_col.add_child(_points_label)
	_trait_checks.clear()
	for t in TRAITS:
		var row := CheckBox.new()
		var cost: int = t.cost
		var cost_text := "-%d pts" % cost if cost > 0 else "+%d pts" % -cost
		row.text = "%s (%s) — %s" % [t.name, cost_text, t.desc]
		row.add_theme_font_size_override("font_size", 12)
		row.toggled.connect(func(_on: bool) -> void: _update_points())
		trait_col.add_child(row)
		_trait_checks[t.id] = row

	# Sandbox + seed row.
	var sandbox_label := Label.new()
	sandbox_label.text = "SANDBOX (PLAN §10.12) — 1.0 is the intended Foundation Standard"
	sandbox_label.add_theme_font_size_override("font_size", 13)
	box.add_child(sandbox_label)
	box.add_child(_sandbox_slider("Needs rate", "needs_rate"))
	box.add_child(_sandbox_slider("Anomaly aggression", "anomaly_aggression"))
	box.add_child(_sandbox_slider("Loot abundance", "loot_abundance"))
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 14)
	toggles.add_child(_sandbox_toggle("Blinking", "blinking_enabled"))
	toggles.add_child(_sandbox_toggle("Ironman", "ironman"))
	toggles.add_child(_sandbox_toggle("Director", "director_enabled"))
	box.add_child(toggles)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "seed code (blank = random)"
	_seed_edit.custom_minimum_size = Vector2(280, 0)
	seed_row.add_child(_seed_edit)
	var begin := _button("PROCESS SUBJECT")
	begin.pressed.connect(_on_start)
	seed_row.add_child(begin)
	var cancel := _button("Cancel")
	cancel.pressed.connect(func() -> void:
		_intake_overlay.queue_free()
		_intake_overlay = null
		_intake_panel = null)
	seed_row.add_child(cancel)
	box.add_child(seed_row)
	_update_points()

func _sandbox_slider(label_text: String, key: String) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 2.0
	slider.step = 0.1
	slider.value = GameState.sandbox.get(key, 1.0)
	slider.custom_minimum_size = Vector2(200, 0)
	var value_label := Label.new()
	value_label.text = "%.1f" % slider.value
	value_label.add_theme_font_size_override("font_size", 12)
	slider.value_changed.connect(func(v: float) -> void:
		GameState.sandbox[key] = v
		value_label.text = "%.1f" % v)
	row.add_child(slider)
	row.add_child(value_label)
	return row

func _sandbox_toggle(label_text: String, key: String) -> Control:
	var check := CheckBox.new()
	check.text = label_text
	check.add_theme_font_size_override("font_size", 12)
	check.button_pressed = GameState.sandbox.get(key, true)
	check.toggled.connect(func(v: bool) -> void: GameState.sandbox[key] = v)
	return check

func _points_available() -> int:
	var points: int = OCCUPATIONS[_occupation_index].points
	for t in TRAITS:
		var check: CheckBox = _trait_checks.get(t.id)
		if check != null and check.button_pressed:
			points -= t.cost
	return points

func _update_points() -> void:
	var points := _points_available()
	_points_label.text = "TRAITS — points available: %d %s" % [
		points, "(take flaws to afford strengths)" if points < 0 else ""]
	_points_label.add_theme_color_override("font_color",
		Color(0.9, 0.35, 0.3) if points < 0 else Color(0.6, 0.85, 0.6))

func _on_start() -> void:
	if _points_available() < 0:
		_update_points()
		return
	GameState.occupation = OCCUPATIONS[_occupation_index].id
	GameState.traits = []
	for t in TRAITS:
		var check: CheckBox = _trait_checks.get(t.id)
		if check != null and check.button_pressed:
			GameState.traits.append(t.id)
	var seed_value := RNG.code_to_seed(_seed_edit.text)
	if seed_value < 0:
		seed_value = int(Time.get_unix_time_from_system()) ^ (Time.get_ticks_usec() << 8)
		seed_value = absi(seed_value) & 0xFFFFFFFF
	start_requested.emit(seed_value, true)

func _show_credits() -> void:
	if _credits_overlay != null:
		_credits_overlay.queue_free()
		_credits_overlay = null
		return
	var wrap := UILayout.center_overlay(self, true)
	_credits_overlay = wrap.root
	_credits_panel = PanelContainer.new()
	_credits_panel.custom_minimum_size = Vector2(720, 480)
	(wrap.center as Control).add_child(_credits_panel)
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
