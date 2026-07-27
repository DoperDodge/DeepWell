## Modal in-run screens (PLAN §15): dual-pane inventory, document viewer
## with progressive declassification, journal, pause/options, the death
## Termination Report, and the descend report. The world does NOT pause for
## inventory or reading — being in a menu is a place you can die.
class_name GameUI
extends Control

enum Screen { NONE, INVENTORY, DOCUMENT, JOURNAL, PAUSE, DEATH, DESCEND, INTAKE }

var screen: int = Screen.NONE

var _modal_root: PanelContainer = null
var _container: Node = null # open WorldContainer / Corpse
var _machine: Node = null   # open SCP914
var _player_list: ItemList
var _other_list: ItemList
var _weight_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"game_ui")
	EventBus.player_died.connect(_on_player_died)
	EventBus.document_open_requested.connect(_open_document)
	EventBus.keycard_acquired.connect(_on_keycard)

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		match screen:
			Screen.NONE:
				if GameState.run_active:
					_open_pause()
			Screen.DEATH, Screen.DESCEND:
				pass # you don't escape the paperwork
			Screen.PAUSE:
				_close()
			_:
				_close()
		get_viewport().set_input_as_handled()
		return
	if screen == Screen.NONE:
		if Input.is_action_just_pressed("inventory"):
			_open_inventory(null)
		elif Input.is_action_just_pressed("journal"):
			_open_journal()
	elif screen == Screen.INVENTORY and Input.is_action_just_pressed("inventory"):
		_close()
	elif screen == Screen.JOURNAL and Input.is_action_just_pressed("journal"):
		_close()

# ------------------------------------------------------------ plumbing

func _open_modal(target_screen: int, pause_world: bool) -> PanelContainer:
	_dismiss()
	screen = target_screen
	GameState.ui_blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if pause_world:
		get_tree().paused = true
	_modal_root = PanelContainer.new()
	_modal_root.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_modal_root)
	AudioManager.play_ui(&"ui_click", -14.0)
	return _modal_root

func _close() -> void:
	_dismiss()
	screen = Screen.NONE
	GameState.ui_blocking = false
	get_tree().paused = false
	_container = null
	_machine = null
	if GameState.run_active and GameState.player != null and not GameState.player.dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _dismiss() -> void:
	if _modal_root != null:
		_modal_root.queue_free()
		_modal_root = null

func _title(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	parent.add_child(label)

func _mono(text: String, size: int = 15) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(640, 0)
	rt.add_theme_font_size_override("normal_font_size", size)
	rt.text = text
	return rt

# ------------------------------------------------------------ inventory

func open_container(container: Node) -> void:
	_open_inventory(container)

func _open_inventory(container: Node) -> void:
	var root := _open_modal(Screen.INVENTORY, false)
	_container = container
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 460)
	root.add_child(box)
	_title(box, "INVENTORY" if container == null else "INVENTORY  ◄►  %s" % str(container.display_name).to_upper())

	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 14)
	box.add_child(panes)

	var left := VBoxContainer.new()
	panes.add_child(left)
	left.add_child(_pane_label("CARRIED"))
	_player_list = ItemList.new()
	_player_list.custom_minimum_size = Vector2(360, 330)
	left.add_child(_player_list)
	_weight_label = Label.new()
	_weight_label.add_theme_font_size_override("font_size", 13)
	left.add_child(_weight_label)

	var right := VBoxContainer.new()
	panes.add_child(right)
	right.add_child(_pane_label("CONTAINER" if container != null else "ACTIONS"))
	if container != null:
		_other_list = ItemList.new()
		_other_list.custom_minimum_size = Vector2(360, 330)
		right.add_child(_other_list)
	else:
		_other_list = null
		var help := Label.new()
		help.text = "Double-click: use item\nRight side appears when\nsearching a container.\n\nDrop puts the item at\nyour feet — weight is\nthe whole game."
		help.add_theme_font_size_override("font_size", 13)
		help.add_theme_color_override("font_color", Color(0.55, 0.57, 0.6))
		right.add_child(help)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	for cfg in [["Use", _act_use], ["Drop", _act_drop], ["Take", _act_take], ["Stash", _act_stash], ["Close", _close]]:
		var b := Button.new()
		b.text = cfg[0]
		b.pressed.connect(cfg[1])
		buttons.add_child(b)
	_player_list.item_activated.connect(func(_i: int) -> void: _act_use())
	if _other_list != null:
		_other_list.item_activated.connect(func(_i: int) -> void: _act_take())
	_refresh_inventory()

func _pane_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
	return label

func _refresh_inventory() -> void:
	if screen != Screen.INVENTORY or _player_list == null:
		return
	var player := GameState.player
	_player_list.clear()
	for it: ItemInstance in player.inventory.items:
		var suffix := ""
		var def := it.definition()
		if def != null and def.has_category(&"light"):
			suffix = "  [%d%%]" % int(it.charge * 100.0)
		_player_list.add_item("%s  (%.1f kg)%s" % [it.display_name(), it.total_weight(), suffix])
	_weight_label.text = "%.1f / %.1f kg" % [player.inventory.total_weight(), player.inventory.capacity_kg]
	if _other_list != null and _container != null:
		_other_list.clear()
		for it: ItemInstance in _container.get_items():
			_other_list.add_item("%s  (%.1f kg)" % [it.display_name(), it.total_weight()])

func _selected_player_item() -> ItemInstance:
	var sel := _player_list.get_selected_items()
	if sel.is_empty():
		return null
	var idx: int = sel[0]
	var items: Array[ItemInstance] = GameState.player.inventory.items
	return items[idx] if idx < items.size() else null

func _act_use() -> void:
	var it := _selected_player_item()
	if it != null:
		GameState.player.inventory.use_item(it)
		_refresh_inventory()

func _act_drop() -> void:
	var it := _selected_player_item()
	if it == null:
		return
	var player := GameState.player
	player.inventory.remove_item(it)
	var pickup := ItemPickup.create("drop_%d_%d" % [Time.get_ticks_msec(), it.def_id.hash()], it)
	player.get_parent().add_child(pickup)
	pickup.global_position = player.global_position + Vector3(0, 0.15, 0)
	EventBus.noise_emitted.emit(player.global_position, 0.2, player, ["drop"])
	_refresh_inventory()

func _act_take() -> void:
	if _container == null or _other_list == null:
		return
	var sel := _other_list.get_selected_items()
	if sel.is_empty():
		return
	var items: Array[ItemInstance] = _container.get_items()
	var idx: int = sel[0]
	if idx >= items.size():
		return
	var it: ItemInstance = items[idx]
	if GameState.player.inventory.add_item(it):
		items.remove_at(idx)
		_container.set_items(items)
	_refresh_inventory()

func _act_stash() -> void:
	if _container == null:
		return
	var it := _selected_player_item()
	if it == null:
		return
	GameState.player.inventory.remove_item(it)
	var items: Array[ItemInstance] = _container.get_items()
	items.append(it)
	_container.set_items(items)
	_refresh_inventory()

# ------------------------------------------------------------ documents

func _open_document(doc_id: StringName) -> void:
	var doc := DocumentDB.get_doc(doc_id)
	if doc.is_empty():
		return
	var root := _open_modal(Screen.DOCUMENT, false)
	GameState.journal[str(doc_id)] = GameState.clearance
	EventBus.document_read.emit(doc_id)
	if GameState.player != null:
		GameState.player.needs.adjust(&"boredom", -18.0) # reading is the cure (§10.3)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(700, 480)
	root.add_child(box)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 430)
	box.add_child(scroll)
	scroll.add_child(_mono(render_document(doc, GameState.clearance)))
	var hint := Label.new()
	hint.text = "[ESC] close  ·  collected to journal (J)  ·  re-read after finding better keycards"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.5, 0.52, 0.55))
	box.add_child(hint)
	AudioManager.play_ui(&"paper", -8.0)

## Progressive declassification renderer (PLAN §8.1). Spans above your
## clearance render their redaction mask; empty masks vanish entirely — you
## can't see the shape of what you're missing.
static func render_document(doc: Dictionary, clearance: int) -> String:
	var out := "[b]%s[/b]\n[color=#777]%s[/color]\n\n" % [
		doc.get("title", "UNTITLED"), str(doc.get("doc_type", "document")).to_upper()]
	for span in doc.get("body", []):
		var required := int(span.get("clearance", 0))
		if required <= clearance:
			out += str(span.get("text", ""))
		else:
			var mask := str(span.get("redacted_as", "██████"))
			if mask != "":
				out += "[bgcolor=#181818][color=#0c0c0c]%s[/color][/bgcolor]" % mask
	return out

# ------------------------------------------------------------ journal

func _open_journal() -> void:
	var root := _open_modal(Screen.JOURNAL, false)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 480)
	root.add_child(box)
	_title(box, "JOURNAL — %s" % GameState.designation)

	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 14)
	box.add_child(panes)

	var doc_list := ItemList.new()
	doc_list.custom_minimum_size = Vector2(300, 400)
	panes.add_child(doc_list)
	var doc_ids: Array = GameState.journal.keys()
	doc_ids.sort()
	for id in doc_ids:
		var doc := DocumentDB.get_doc(StringName(id))
		var marker := ""
		if int(GameState.journal[id]) < GameState.clearance and DocumentDB.has_redactions_at(StringName(id), int(GameState.journal[id])):
			marker = "  ● NEW INTEL"
		doc_list.add_item("%s%s" % [doc.get("title", id), marker])
	doc_list.item_activated.connect(func(i: int) -> void:
		_open_document(StringName(doc_ids[i])))

	var side := VBoxContainer.new()
	panes.add_child(side)
	side.add_child(_pane_label("ANOMALY LOG"))
	var anomalies: Array = GameState.stats.anomalies_witnessed
	var anomaly_text := "Nothing confirmed yet.\nStay that way." if anomalies.is_empty() else ""
	for a in anomalies:
		anomaly_text += "%s — %s\n" % [a, _anomaly_note(a)]
	var anomaly_label := Label.new()
	anomaly_label.text = anomaly_text
	anomaly_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	anomaly_label.custom_minimum_size = Vector2(400, 0)
	anomaly_label.add_theme_font_size_override("font_size", 13)
	side.add_child(anomaly_label)
	side.add_child(_pane_label("SITE LOG"))
	var log_text := ""
	var entries: Array = FacilityState.incident_log
	for i in range(maxi(entries.size() - 8, 0), entries.size()):
		log_text += "[%s] %s\n" % [entries[i].t, entries[i].text]
	var log_label := Label.new()
	log_label.text = log_text if log_text != "" else "No incidents recorded. Yet."
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	log_label.custom_minimum_size = Vector2(400, 0)
	log_label.add_theme_font_size_override("font_size", 12)
	log_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))
	side.add_child(log_label)

func _anomaly_note(designation: StringName) -> String:
	match designation:
		&"SCP-173":
			return "Moves when unobserved. Blinking counts. — unverified"
		&"SCP-1048":
			return "Small bear. Waves. Draws. Apparently harmless. Apparently."
	return "insufficient observation"

# ------------------------------------------------------------ pause

func _open_pause() -> void:
	var root := _open_modal(Screen.PAUSE, true)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	_title(box, "PAUSED — SITE-104")

	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(_close)
	box.add_child(resume)

	box.add_child(_slider_row("Field of view", 70.0, 110.0, Settings.fov(),
		func(v: float) -> void: Settings.set_value("fov", v)))
	box.add_child(_slider_row("Mouse sensitivity", 0.0005, 0.006, Settings.mouse_sensitivity(),
		func(v: float) -> void: Settings.set_value("mouse_sensitivity", v)))
	box.add_child(_slider_row("Master volume", 0.0, 1.0, Settings.master_volume(),
		func(v: float) -> void:
			Settings.set_value("master_volume", v)
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001)))))
	box.add_child(_toggle_row("Film grain", Settings.film_grain(),
		func(v: bool) -> void: Settings.set_value("film_grain", v)))
	box.add_child(_toggle_row("Head bob", Settings.head_bob() > 0.0,
		func(v: bool) -> void: Settings.set_value("head_bob", 1.0 if v else 0.0)))
	box.add_child(_toggle_row("Subtitles", Settings.show_subtitles(),
		func(v: bool) -> void: Settings.set_value("subtitles", v)))

	var quit := Button.new()
	quit.text = "Save && quit to menu"
	quit.pressed.connect(func() -> void:
		SaveManager.save_run()
		_close()
		GameState.end_run(&"quit")
		EventBus.menu_requested.emit())
	box.add_child(quit)

func _slider_row(label_text: String, min_v: float, max_v: float, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = (max_v - min_v) / 100.0
	slider.value = value
	slider.custom_minimum_size = Vector2(200, 0)
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return row

func _toggle_row(label_text: String, value: bool, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	var check := CheckButton.new()
	check.button_pressed = value
	check.toggled.connect(on_change)
	row.add_child(check)
	return row

# ------------------------------------------------------------ SCP-914

func open_914_intake(machine: Node) -> void:
	var root := _open_modal(Screen.INTAKE, false)
	_machine = machine
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 420)
	root.add_child(box)
	_title(box, "SCP-914 — INTAKE BOOTH  [ %s ]" % SCP914.SETTINGS[machine.setting_index])
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(440, 300)
	box.add_child(list)
	var items: Array[ItemInstance] = GameState.player.inventory.items
	for it in items:
		list.add_item(it.display_name())
	var process_one := func() -> void:
		var sel := list.get_selected_items()
		if sel.is_empty():
			return
		var idx: int = sel[0]
		if idx < items.size():
			var msg: String = machine.process_item(GameState.player, items[idx])
			EventBus.toast.emit(msg)
		_close()
	var buttons := HBoxContainer.new()
	var run_btn := Button.new()
	run_btn.text = "Process"
	run_btn.pressed.connect(process_one)
	buttons.add_child(run_btn)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_close)
	buttons.add_child(cancel)
	box.add_child(buttons)
	list.item_activated.connect(func(_i: int) -> void: process_one.call())

# ------------------------------------------------------------ death / descend

func _on_player_died(cause: String, floor_index: int, _pos: Vector3) -> void:
	GameState.end_run(&"death")
	var tw := create_tween()
	tw.tween_interval(1.6) # let the sound land in the dark
	tw.tween_callback(func() -> void: _show_death(cause, floor_index))

func _show_death(cause: String, floor_index: int) -> void:
	var root := _open_modal(Screen.DEATH, true)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(680, 0)
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	box.add_child(_mono(_termination_report(cause, floor_index), 14))

	var again := Button.new()
	again.text = "Process next D-Class into Site-104  (same site — your corpse is still there)"
	again.pressed.connect(func() -> void:
		_close()
		EventBus.restart_requested.emit(true))
	box.add_child(again)
	var menu_btn := Button.new()
	menu_btn.text = "Abandon site — main menu"
	menu_btn.pressed.connect(func() -> void:
		_close()
		EventBus.menu_requested.emit())
	box.add_child(menu_btn)

func _termination_report(cause: String, floor_index: int) -> String:
	var stats := GameState.stats
	var hours := TimeManager.hours_survived()
	var anomalies: Array = stats.anomalies_witnessed
	var remark := _admin_remark(cause)
	return "\n".join([
		"[color=#8a8a8a]SCP FOUNDATION — INTERNAL DOCUMENT[/color]",
		"[b]SUBJECT TERMINATION REPORT — SITE-104[/b]",
		"",
		"Subject:            %s (Class D)" % GameState.designation,
		"Termination cause:  %s" % cause,
		"Location:           Floor %d — Light Containment" % floor_index,
		"Duration on site:   %d h %02d min" % [int(hours), int(fmod(hours, 1.0) * 60.0)],
		"Distance traveled:  %.0f m" % stats.distance_walked_m,
		"Documents accessed: %d" % stats.documents_read,
		"Anomalies engaged:  %s" % (", ".join(anomalies) if not anomalies.is_empty() else "none confirmed"),
		"Site fatalities to date: %d" % FacilityState.site_deaths,
		"",
		"Remains:            unrecovered. Standard notation applied.",
		"Administrator note: [i]%s[/i]" % remark,
		"",
		"[color=#8a8a8a]Seed %s — quote it to relive this site. Personnel are reminded that" % GameState.seed_code(),
		"D-Class inventory is Foundation property and remains with the body.[/color]",
	])

func _admin_remark(cause: String) -> String:
	if cause.contains("cervical"):
		return "Subject was advised not to blink. Subject blinked."
	if cause.contains("exsanguination"):
		return "Requisition: mops, Sector 3. Again."
	if cause.contains("septicemia"):
		return "Post-mortem note: the infirmary was two doors away."
	return "No notable observations. Next."

func show_descend() -> void:
	GameState.end_run(&"descend")
	var root := _open_modal(Screen.DESCEND, true)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(680, 0)
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)
	var hours := TimeManager.hours_survived()
	box.add_child(_mono("\n".join([
		"[color=#8a8a8a]SCP FOUNDATION — AUTOMATED TRACKING BULLETIN[/color]",
		"[b]SUBJECT MOVEMENT REPORT — SITE-104[/b]",
		"",
		"Subject %s has accessed Stairwell S-3." % GameState.designation,
		"Biometric implant signal descending toward Floor 4 — Research && Testing.",
		"Elapsed time on Floor 3: %d h %02d min. Documents recovered: %d." % [
			int(hours), int(fmod(hours, 1.0) * 60.0), GameState.stats.documents_read],
		"",
		"[i]Floor 4 lighting is on emergency power. SCP-049 containment status: unverified.",
		"This is where the vertical slice ends — the descent continues in the next phase.[/i]",
		"",
		"Seed %s — the site remembers you." % GameState.seed_code(),
	]), 14))
	var menu_btn := Button.new()
	menu_btn.text = "Main menu"
	menu_btn.pressed.connect(func() -> void:
		_close()
		EventBus.menu_requested.emit())
	box.add_child(menu_btn)

func _on_keycard(level: int) -> void:
	EventBus.toast.emit("Keycard Level %d — new areas and new paragraphs open." % level)
