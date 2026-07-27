## SCP-914 — "The Clockworks" · Safe (PLAN §6.5). The crafting-adjacent
## gambling system: five settings, item in, transformed item out. Unmapped
## items fall to category tables, then to destruction. Very Fine carries a
## 5% chance of something unrelated and unsettling. Every use is logged to
## the facility incident record the player can find later.
class_name SCP914
extends Node3D

const SETTINGS := ["Rough", "Coarse", "1:1", "Fine", "Very Fine"]
const ANOMALOUS_OUTPUTS: Array[StringName] = [&"anomalous_lump", &"cold_key", &"origami_crane"]

var setting_index: int = 2
var busy: bool = false

var _dial_label: Label3D
var _intake: StaticBody3D

func _ready() -> void:
	add_to_group(&"persistable")
	# The machine: a massive brass-and-iron cabinet between two booths.
	_add_box(Vector3(0, 1.5, 0), Vector3(3.6, 3.0, 2.2), Color(0.45, 0.34, 0.16), 0.4, 0.55)
	_add_box(Vector3(-2.6, 0.9, 0), Vector3(1.4, 1.8, 1.6), Color(0.3, 0.3, 0.32), 0.7, 0.4) # intake booth
	_add_box(Vector3(2.6, 0.9, 0), Vector3(1.4, 1.8, 1.6), Color(0.3, 0.3, 0.32), 0.7, 0.4)  # output booth
	for i in 5:
		_add_box(Vector3(-1.4 + i * 0.7, 3.15, 0), Vector3(0.25, 0.3 + (i % 3) * 0.2, 0.25),
			Color(0.55, 0.42, 0.2), 0.8, 0.3) # gear housings on top

	var plate := Label3D.new()
	plate.text = "SCP-914\n\"THE CLOCKWORKS\"\nDO NOT INSERT ORGANIC MATERIAL"
	plate.font_size = 30
	plate.modulate = Color(0.85, 0.8, 0.6)
	plate.position = Vector3(0, 2.4, 1.15)
	add_child(plate)

	_dial_label = Label3D.new()
	_dial_label.font_size = 44
	_dial_label.modulate = Color(0.95, 0.75, 0.3)
	_dial_label.position = Vector3(0, 1.5, 1.15)
	add_child(_dial_label)
	_update_dial()

	# Dial (interactable): cycles the setting.
	var dial := StaticBody3D.new()
	dial.collision_layer = 4
	dial.set_script(load("res://src/scps/machines/scp_914_dial.gd"))
	var dial_shape := CollisionShape3D.new()
	var dial_box := BoxShape3D.new()
	dial_box.size = Vector3(0.9, 0.9, 0.4)
	dial_shape.shape = dial_box
	dial.add_child(dial_shape)
	add_child(dial)
	dial.position = Vector3(0, 1.35, 1.1)

	# Intake booth (interactable): choose an item to process.
	_intake = StaticBody3D.new()
	_intake.collision_layer = 4
	_intake.set_script(load("res://src/scps/machines/scp_914_intake.gd"))
	var intake_shape := CollisionShape3D.new()
	var intake_box := BoxShape3D.new()
	intake_box.size = Vector3(1.5, 1.9, 1.7)
	intake_shape.shape = intake_box
	intake_shape.position.y = 0.95
	_intake.add_child(intake_shape)
	add_child(_intake)
	_intake.position = Vector3(-2.6, 0, 0)

func _add_box(pos: Vector3, size: Vector3, color: Color, metallic: float, rough: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = rough
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)
	body.position = pos

func cycle_setting() -> void:
	if busy:
		return
	setting_index = (setting_index + 1) % SETTINGS.size()
	AudioManager.play_3d(&"ui_click", global_position, -4.0, 0.7)
	_update_dial()

func _update_dial() -> void:
	_dial_label.text = "SETTING: [ %s ]" % SETTINGS[setting_index]

## Runs one item through. Returns a result description for the UI.
func process_item(player: Node, inst: ItemInstance) -> String:
	if busy:
		return "The machine is running."
	busy = true
	player.inventory.remove_item(inst)
	AudioManager.play_3d(&"machine_run", global_position, -2.0)
	EventBus.noise_emitted.emit(global_position, 0.5, self, ["machine"])
	var result_id := _transform(inst)
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_callback(func() -> void:
		busy = false
		var text := "The output booth is empty. Whatever went in is simply gone."
		if result_id != &"" and ItemDB.exists(result_id):
			var out := ItemInstance.new(result_id, 1)
			player.inventory.add_item(out)
			text = "The booth opens: %s." % out.display_name()
		EventBus.toast.emit(text)
		FacilityState.log_incident(
			"SCP-914 operated by %s. Setting: %s. Input: %s. Output: %s." % [
				GameState.designation, SETTINGS[setting_index],
				inst.definition().display_name,
				ItemDB.get_def(result_id).display_name if ItemDB.exists(result_id) else "none recovered",
			]))
	return "The Clockworks accepts your %s. Gears turn." % inst.definition().display_name

func _transform(inst: ItemInstance) -> StringName:
	var def := inst.definition()
	var rng := RNG.stream(&"scp_914")
	match SETTINGS[setting_index]:
		"Rough":
			return def.downgrade_result if def.downgrade_result != &"" else &"scrap_metal"
		"Coarse":
			if def.downgrade_result != &"":
				return def.downgrade_result
			return &"scrap_metal" if rng.randf() < 0.5 else &"scrap_plastic"
		"1:1":
			# Repairs/cleans/rerolls in kind.
			inst.condition = def.max_condition
			inst.charge = 1.0
			if def.is_keycard():
				return def.id # pristine copy of the same card
			var same_cat := _random_of_category(def, rng)
			return same_cat if same_cat != &"" else def.id
		"Fine":
			return def.upgrade_result if def.upgrade_result != &"" else _category_upgrade(def)
		"Very Fine":
			if rng.randf() < 0.05:
				return ANOMALOUS_OUTPUTS[rng.randi_range(0, ANOMALOUS_OUTPUTS.size() - 1)]
			if def.refine_result != &"":
				return def.refine_result
			var fine := def.upgrade_result if def.upgrade_result != &"" else _category_upgrade(def)
			if fine != &"" and ItemDB.exists(fine):
				var fine_def := ItemDB.get_def(fine)
				if fine_def.refine_result != &"":
					return fine_def.refine_result
			return fine
	return &""

func _category_upgrade(def: ItemDefinition) -> StringName:
	if def.has_category(&"medical"):
		return &"suture_kit"
	if def.has_category(&"material"):
		return &"crowbar"
	if def.has_category(&"battery"):
		return &"battery"
	return &""

func _random_of_category(def: ItemDefinition, rng: RandomNumberGenerator) -> StringName:
	if def.categories.is_empty():
		return &""
	var cat: StringName = def.categories[0]
	var candidates: Array = []
	for id in ItemDB.all_ids():
		if ItemDB.get_def(id).has_category(cat):
			candidates.append(id)
	if candidates.is_empty():
		return &""
	return candidates[rng.randi_range(0, candidates.size() - 1)]

var persist_id: String = "scp_914"

func serialize_state() -> Dictionary:
	return {"setting": setting_index}

func deserialize_state(d: Dictionary) -> void:
	setting_index = int(d.get("setting", 2))
	_update_dial()
