## In-run HUD (PLAN §15): diegetic-first, no health bar. Biomonitor moodles
## top-right, interact prompt center, eyelid overlay, screen-effect stack,
## toasts and subtitles. Reads player state; never writes it.
## Layout is container-driven throughout — no manual position offsets
## (see UILayout for why).
class_name HUD
extends Control

var _player: Node = null

var _fx_rect: ColorRect
var _fx_mat: ShaderMaterial
var _lid_top: ColorRect
var _lid_bottom: ColorRect
var _prompt: Label
var _hold_bar: ProgressBar
var _stamina_bar: ProgressBar
var _moodle_box: VBoxContainer
var _toast_box: VBoxContainer
var _subtitle: Label
var _clock: Label
var _debug: Label
var _floor_title: Label
var _time: float = 0.0

func _ready() -> void:
	UILayout.fullscreen(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.player_spawned.connect(func(p: Node3D) -> void: _player = p)
	EventBus.floor_generated.connect(_on_floor_generated)
	EventBus.toast.connect(_on_toast)
	EventBus.subtitle.connect(func(speaker: String, text: String) -> void: _show_subtitle(speaker, text))
	EventBus.pa_announcement.connect(func(text: String) -> void: _show_subtitle("PA SYSTEM", text))
	_build()
	if GameState.player != null:
		_player = GameState.player

func _full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _build() -> void:
	# Post-processing overlay (below all readable UI).
	_fx_rect = ColorRect.new()
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = load("res://assets/shaders/screen_fx.gdshader")
	_fx_rect.material = _fx_mat
	_full_rect(_fx_rect)

	# Eyelids: two black rects meeting in the middle of the screen.
	_lid_top = ColorRect.new()
	_lid_top.color = Color.BLACK
	_lid_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lid_top)
	_lid_bottom = ColorRect.new()
	_lid_bottom.color = Color.BLACK
	_lid_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lid_bottom)

	# Prompt + hold bar: centered stack, pushed below the crosshair by an
	# asymmetric top spacer.
	var prompt_center := CenterContainer.new()
	_full_rect(prompt_center)
	var prompt_stack := VBoxContainer.new()
	prompt_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_stack.add_theme_constant_override("separation", 10)
	prompt_center.add_child(prompt_stack)
	prompt_stack.add_child(_spacer(150))
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt.add_theme_font_size_override("font_size", 17)
	_prompt.add_theme_color_override("font_color", Color(0.92, 0.9, 0.82))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 4)
	prompt_stack.add_child(_prompt)
	_hold_bar = ProgressBar.new()
	_hold_bar.custom_minimum_size = Vector2(180, 8)
	_hold_bar.show_percentage = false
	_hold_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hold_bar.visible = false
	prompt_stack.add_child(_hold_bar)

	# Floor title: top-center band.
	var top_stack := VBoxContainer.new()
	top_stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	_full_rect(top_stack)
	top_stack.add_child(_spacer(84))
	_floor_title = Label.new()
	_floor_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floor_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_floor_title.add_theme_font_size_override("font_size", 34)
	_floor_title.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	_floor_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_floor_title.add_theme_constant_override("outline_size", 6)
	_floor_title.modulate.a = 0.0
	top_stack.add_child(_floor_title)

	# Bottom-center band: subtitle above the stamina sliver.
	var bottom_stack := VBoxContainer.new()
	bottom_stack.alignment = BoxContainer.ALIGNMENT_END
	_full_rect(bottom_stack)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	_subtitle.custom_minimum_size = Vector2(700, 0)
	_subtitle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_subtitle.add_theme_font_size_override("font_size", 16)
	_subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_subtitle.add_theme_constant_override("outline_size", 5)
	_subtitle.modulate.a = 0.0
	bottom_stack.add_child(_subtitle)
	bottom_stack.add_child(_spacer(14))
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(220, 5)
	_stamina_bar.show_percentage = false
	_stamina_bar.max_value = 100.0
	_stamina_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stamina_bar.modulate = Color(0.8, 0.85, 0.7, 0.0)
	bottom_stack.add_child(_stamina_bar)
	bottom_stack.add_child(_spacer(38))

	# Biomonitor: top-right margin block.
	var bio_margin := MarginContainer.new()
	bio_margin.add_theme_constant_override("margin_right", 16)
	bio_margin.add_theme_constant_override("margin_top", 14)
	_full_rect(bio_margin)
	var bio_panel := VBoxContainer.new()
	bio_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	bio_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bio_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bio_margin.add_child(bio_panel)
	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.size_flags_horizontal = Control.SIZE_SHRINK_END
	_clock.add_theme_font_size_override("font_size", 13)
	_clock.modulate = Color(0.6, 0.75, 0.65, 0.85)
	bio_panel.add_child(_clock)
	_moodle_box = VBoxContainer.new()
	_moodle_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	bio_panel.add_child(_moodle_box)

	# Toasts: bottom-left margin block.
	var toast_margin := MarginContainer.new()
	toast_margin.add_theme_constant_override("margin_left", 18)
	toast_margin.add_theme_constant_override("margin_bottom", 140)
	_full_rect(toast_margin)
	_toast_box = VBoxContainer.new()
	_toast_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_toast_box.size_flags_vertical = Control.SIZE_SHRINK_END
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_margin.add_child(_toast_box)

	# Debug overlay: top-left.
	var debug_margin := MarginContainer.new()
	debug_margin.add_theme_constant_override("margin_left", 12)
	debug_margin.add_theme_constant_override("margin_top", 12)
	_full_rect(debug_margin)
	_debug = Label.new()
	_debug.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_debug.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_debug.add_theme_font_size_override("font_size", 12)
	_debug.modulate = Color(0.5, 1.0, 0.6, 0.9)
	_debug.visible = false
	debug_margin.add_child(_debug)

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _on_floor_generated(floor_index: int) -> void:
	var floor_def := load("res://data/floors/floor_%d.tres" % floor_index) as FloorDef
	if floor_def == null:
		return
	_floor_title.text = "FLOOR %d — %s" % [floor_index, floor_def.zone_name.to_upper()]
	_floor_title.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_floor_title, "modulate:a", 1.0, 1.2)
	tw.tween_interval(3.5)
	tw.tween_property(_floor_title, "modulate:a", 0.0, 1.5)

func _process(delta: float) -> void:
	_time += delta
	if _player == null or not is_instance_valid(_player):
		return
	# Eyelids follow blink closure; suppression pressure narrows the eyes.
	var vp := get_viewport_rect().size
	var closure: float = _player.blink.closure
	var squint: float = _player.blink.pressure * 0.12
	var lid := vp.y * 0.5 * clampf(closure + squint, 0.0, 1.0)
	_lid_top.position = Vector2.ZERO
	_lid_top.size = Vector2(vp.x, lid)
	_lid_bottom.size = Vector2(vp.x, lid)
	_lid_bottom.position = Vector2(0, vp.y - lid)

	_prompt.text = _player.interaction.current_prompt
	var hold: float = _player.interaction.hold_progress
	_hold_bar.visible = hold >= 0.0
	if hold >= 0.0:
		_hold_bar.value = hold * 100.0

	var stamina: float = _player.movement.stamina
	_stamina_bar.value = stamina
	var stamina_alpha := 0.75 if stamina < 99.0 else 0.0
	_stamina_bar.modulate.a = lerpf(_stamina_bar.modulate.a, stamina_alpha, delta * 4.0)

	_clock.text = "%s   %s   SITE-104" % [GameState.designation, TimeManager.clock_string()]

	# Screen effects from body state.
	var sanity: float = _player.sanity.sanity
	var pain: float = _player.get_stat(&"pain")
	_fx_mat.set_shader_parameter("time_seed", fmod(_time, 600.0))
	_fx_mat.set_shader_parameter("aberration", remap(clampf(sanity, 0.0, 60.0), 60.0, 0.0, 0.0, 5.0))
	_fx_mat.set_shader_parameter("desaturate", remap(clampf(sanity, 0.0, 50.0), 50.0, 0.0, 0.0, 0.45))
	var grain := 0.05 if Settings.film_grain() else 0.0
	_fx_mat.set_shader_parameter("grain_strength", grain)
	_fx_mat.set_shader_parameter("thermal", 1.0 if _player.thermal_on else 0.0)
	_fx_mat.set_shader_parameter("vignette_strength",
		clampf(0.3 + pain * 0.004 + (100.0 - _player.movement.stamina) * 0.002, 0.0, 0.75))

	if Input.is_action_just_pressed("debug_overlay"):
		_debug.visible = not _debug.visible
	if _debug.visible:
		_update_debug()
	_update_moodles()

func _update_moodles() -> void:
	var active: Array = _player.moodles.active()
	var signature := ""
	for m in active:
		signature += "%s%d" % [m.def.id, m.level]
	if _moodle_box.get_meta("sig", "") == signature:
		return
	_moodle_box.set_meta("sig", signature)
	for child in _moodle_box.get_children():
		child.queue_free()
	for m in active:
		var def: MoodleDefinition = m.def
		var level: int = m.level
		var row := Label.new()
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_theme_font_size_override("font_size", 14)
		var pips := "".rpad(level, "▮")
		row.text = "%s %s  %s" % [def.label_for(level), pips, def.display_name]
		row.add_theme_color_override("font_color", def.color.lightened(0.1 * (4 - level)))
		row.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		row.add_theme_constant_override("outline_size", 3)
		_moodle_box.add_child(row)

func _on_toast(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	_toast_box.add_child(label)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(label, "modulate:a", 0.0, 1.0)
	tw.tween_callback(label.queue_free)
	while _toast_box.get_child_count() > 5:
		_toast_box.get_child(0).free()

func _show_subtitle(speaker: String, text: String) -> void:
	if not Settings.show_subtitles():
		return
	_subtitle.text = "[%s]  %s" % [speaker, text]
	var tw := create_tween()
	_subtitle.modulate.a = 1.0
	tw.tween_interval(clampf(text.length() * 0.06, 3.0, 9.0))
	tw.tween_property(_subtitle, "modulate:a", 0.0, 0.8)

func _update_debug() -> void:
	var lines: Array[String] = []
	lines.append("fps %d   seed %s" % [Engine.get_frames_per_second(), GameState.seed_code()])
	lines.append("tension %.2f  stalk %.2f" % [Director.tension, Director.stalk_pressure()])
	if _player != null and GameState.grid != null:
		var cell: Vector2i = GameState.grid.world_to_cell(_player.global_position)
		lines.append("cell %s  light %.2f" % [cell, LightProbe.sample_at(_player.global_position + Vector3.UP * 1.2)])
		lines.append("blink p %.2f  stamina %.0f" % [_player.blink.pressure, _player.movement.stamina])
	for scp in get_tree().get_nodes_in_group(&"observable"):
		if scp is SCP173:
			lines.append("173: obs %.2f  hunting %s  dist %.1f" % [
				scp.total_observation(), scp.hunting,
				scp.global_position.distance_to(_player.global_position)])
	_debug.text = "\n".join(lines)
