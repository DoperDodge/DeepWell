## The way down. Behind the exit blast door; interacting advances the run to
## the next floor — or, on the final floor, into the ending (PLAN §6.6-lite).
class_name StairwellExit
extends StaticBody3D

var floor_def: FloorDef = null

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 3.0)
	shape.shape = box
	shape.position.y = 1.5
	add_child(shape)
	# Descending stair suggestion: dark dropping slabs.
	for i in 5:
		var step := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.4, 0.25, 0.6)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.19, 0.2).darkened(i * 0.12)
		mesh.material = mat
		step.mesh = mesh
		step.position = Vector3(0, -0.15 - i * 0.28, i * 0.6 - 1.2)
		add_child(step)
	var sign_label := Label3D.new()
	var floor_index := GameState.floor_index
	if floor_def != null and floor_def.final_floor:
		sign_label.text = "DEEP SERVICE ELEVATOR\nTHE WELL — AUTHORIZED DESCENT ONLY\n▼ ▼ ▼"
	else:
		sign_label.text = "STAIRWELL S-%d\n▼ FLOOR %d ▼" % [floor_index, floor_index + 1]
	sign_label.font_size = 36
	sign_label.modulate = Color(0.9, 0.85, 0.6)
	sign_label.position = Vector3(0, 2.4, -1.4)
	add_child(sign_label)

func get_prompt(_player: Node) -> String:
	if floor_def != null and floor_def.exit_label != "":
		return "[E] " + floor_def.exit_label
	return "[E] Descend"

func interact(_player: Node) -> void:
	EventBus.descend_requested.emit()
