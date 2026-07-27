## Layout guard for top-level Controls that live directly under a
## CanvasLayer. Anchor presets alone proved unreliable there on real
## windows (v0.5.0 shipped with the main menu laid out against a
## zero-sized parent — see PLAYTEST_LOG). This pins the control to the
## full viewport explicitly and keeps it pinned across window resizes.
class_name UILayout
extends RefCounted

static func fullscreen(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	if c.is_inside_tree():
		_pin(c)
	else:
		c.tree_entered.connect(func() -> void: _pin(c), CONNECT_ONE_SHOT)

static func _pin(c: Control) -> void:
	_resize(c)
	c.get_viewport().size_changed.connect(func() -> void:
		if is_instance_valid(c) and c.is_inside_tree():
			_resize(c))

## Only intervenes when the anchor pass has visibly failed (degenerate
## size / off-origin root) — the healthy path stays anchor-driven.
static func _resize(c: Control) -> void:
	var target := c.get_viewport_rect().size
	if c.size.x < target.x * 0.5 or c.size.y < target.y * 0.5 or c.position != Vector2.ZERO:
		c.position = Vector2.ZERO
		c.set_deferred(&"size", target)

## A full-viewport child container that centers whatever is put inside it.
## mouse_blocking=true also dims and swallows clicks (modal backdrops).
static func center_overlay(parent: Control, mouse_blocking: bool = false) -> Dictionary:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	fullscreen(root)
	if mouse_blocking:
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	return {"root": root, "center": center}
