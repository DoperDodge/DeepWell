## The way down. Behind the exit blast door; interacting ends the floor.
## In the vertical slice, descending concludes the run with a Foundation
## incident report (deeper floors are later phases — PLAN §19).
class_name StairwellExit
extends StaticBody3D

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
	sign_label.text = "STAIRWELL S-3\nHEAVY CONTAINMENT ACCESS\n▼ FLOOR 4 ▼"
	sign_label.font_size = 36
	sign_label.modulate = Color(0.9, 0.85, 0.6)
	sign_label.position = Vector3(0, 2.4, -1.4)
	add_child(sign_label)

func get_prompt(_player: Node) -> String:
	return "[E] Descend to Floor 4"

func interact(_player: Node) -> void:
	SaveManager.delete_save() # the floor is done either way
	get_tree().call_group(&"game_ui", "show_descend")
