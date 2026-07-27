## The selection dial on SCP-914's face.
extends StaticBody3D

func get_prompt(_player: Node) -> String:
	var machine := get_parent() as SCP914
	return "[E] Turn dial (now: %s)" % SCP914.SETTINGS[machine.setting_index]

func interact(_player: Node) -> void:
	(get_parent() as SCP914).cycle_setting()
