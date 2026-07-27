## Interacting with SCP-1048. It likes you. That should worry you.
extends StaticBody3D

func get_prompt(_player: Node) -> String:
	return "[E] Wave back"

func interact(player: Node) -> void:
	AudioManager.play_3d(&"squeak", global_position, -6.0, 1.2)
	EventBus.toast.emit("It bounces, delighted. It pats your shoe.")
	player.sanity.adjust(1.0)
	player.needs.adjust(&"boredom", -8.0)
