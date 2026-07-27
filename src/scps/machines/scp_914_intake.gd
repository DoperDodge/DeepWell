## SCP-914's intake booth — asks the game UI to pick an inventory item.
extends StaticBody3D

func get_prompt(_player: Node) -> String:
	var machine := get_parent() as SCP914
	if machine.busy:
		return "The Clockworks is turning..."
	return "[E] Place an item in the intake booth"

func interact(_player: Node) -> void:
	var machine := get_parent() as SCP914
	if machine.busy:
		return
	get_tree().call_group(&"game_ui", "open_914_intake", machine)
