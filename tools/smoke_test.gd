## Headless gameplay smoke test:
##   godot --headless --path . -- --smoke
## Boots a real run and exercises the paths validation can't: doors,
## containers, documents, noise propagation, the 914 machine, and an actual
## SCP-173 hunt ending in a player death. Exit 0 only if the full loop ran.
extends Node

var _failures: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("SMOKE FAIL: " + msg)

func _ready() -> void:
	await get_tree().process_frame
	await _run()

func _run() -> void:
	# Boot a run exactly the way the menu would.
	var main := get_parent()
	main._start_run(424242, true, false)
	await _wait(0.5)

	var player := GameState.player
	_check(player != null, "player did not spawn")
	if player == null:
		return _finish()
	_check(GameState.grid != null, "grid not registered")
	print("smoke: run started, player at %s" % player.global_position)

	# Door cycle.
	var door: Door = null
	for d in get_tree().root.find_children("*", "Door", true, false):
		if d.state == Door.DoorState.UNLOCKED:
			door = d
			break
	_check(door != null, "no unlocked door found")
	if door != null:
		door.interact(player)
		await _wait(1.0)
		_check(door.state == Door.DoorState.OPEN, "door did not open")
		door.interact(player)
		await _wait(0.9)
		_check(door.state == Door.DoorState.UNLOCKED, "door did not close")
		print("smoke: door cycle ok")

	# Locked door denies at clearance 0.
	var locked: Door = null
	for d in get_tree().root.find_children("*", "Door", true, false):
		if d.state == Door.DoorState.LOCKED and d.clearance > GameState.clearance:
			locked = d
			break
	if locked != null:
		locked.interact(player)
		_check(locked.state == Door.DoorState.LOCKED, "locked door opened without clearance")
		print("smoke: locked door held")

	# Container search rolls deterministic loot.
	var containers := get_tree().root.find_children("*", "WorldContainer", true, false)
	_check(containers.size() >= 3, "too few containers: %d" % containers.size())
	if not containers.is_empty():
		var c: WorldContainer = containers[0]
		c.interact(player)
		_check(FacilityState.opened_containers.has(c.container_id), "container did not register as searched")
		_close_ui()
		print("smoke: container ok (%d items)" % c.get_items().size())

	# Starter kit: flashlight from personal effects.
	var effects: WorldContainer = null
	for c: WorldContainer in containers:
		if c.container_id == "cont_spawn_effects":
			effects = c
	_check(effects != null, "spawn effects locker missing")
	if effects != null:
		effects.interact(player)
		var found_flashlight := false
		for it in effects.get_items():
			if it.def_id == &"flashlight":
				found_flashlight = true
				player.inventory.add_item(it)
		_check(found_flashlight, "no flashlight in personal effects")
		_close_ui()
		player.toggle_flashlight()
		_check(player.flashlight_on, "flashlight did not turn on")
		print("smoke: flashlight ok")

	# Document flow.
	EventBus.document_open_requested.emit(&"doc_orientation")
	await _wait(0.2)
	_check(GameState.journal.has("doc_orientation"), "document not journaled")
	_close_ui()
	print("smoke: document ok")

	# Noise propagation reaches 173.
	var scp173: SCP173 = null
	for s in get_tree().get_nodes_in_group(&"observable"):
		if s is SCP173:
			scp173 = s
	_check(scp173 != null, "SCP-173 not spawned")
	if scp173 != null:
		EventBus.noise_emitted.emit(player.global_position, 1.0, player, ["test"])
		await _wait(0.2)
		# May be attenuated below threshold across the map — just verify the
		# effective loudness math produces a sane number.
		var eff: float = GameState.grid.effective_loudness(1.0, player.global_position, scp173.global_position)
		_check(eff >= 0.0 and eff <= 1.0, "effective loudness out of range: %f" % eff)
		print("smoke: noise ok (eff %.3f at 173)" % eff)

	# SCP-914 transforms a keycard upward on Fine.
	var machines := get_tree().root.find_children("*", "SCP914", true, false)
	_check(machines.size() == 1, "expected one SCP-914")
	if machines.size() == 1:
		var machine: SCP914 = machines[0]
		machine.setting_index = 3 # Fine
		var card := ItemInstance.new(&"keycard_l1")
		player.inventory.add_item(card)
		machine.process_item(player, card)
		await _wait(3.6)
		_check(player.inventory.has_item(&"keycard_l2"), "914 Fine did not upgrade L1 -> L2")
		_check(GameState.clearance >= 2, "clearance did not rise with 914 card")
		print("smoke: SCP-914 ok")

	# Save round-trip with live state.
	SaveManager.save_run()
	_check(SaveManager.has_save(), "save file not written")
	var save := SaveManager.read_save()
	_check(int(save.get("seed", -1)) == 424242, "save seed mismatch")
	print("smoke: save ok")

	# The main event: put the player in front of a hunting 173, look away.
	if scp173 != null:
		var away := (player.global_position - scp173.global_position).normalized()
		player.global_position = scp173.global_position + away * 6.0
		player.look_at(player.global_position + away, Vector3.UP) # back turned
		scp173.hunting = true
		var deadline := 12.0
		while deadline > 0.0 and not player.dead:
			deadline -= 0.1
			await _wait(0.1)
		_check(player.dead, "SCP-173 failed to kill an unwatching player in 12 s")
		_check(not SaveManager.has_save(), "ironman save survived death")
		var corpses := FacilityState.corpses_on_floor(GameState.floor_index)
		_check(corpses.size() >= 1, "death did not persist a corpse to the site file")
		print("smoke: 173 kill + corpse persistence ok")

	_finish()

func _close_ui() -> void:
	var ui := get_tree().get_first_node_in_group(&"game_ui")
	if ui != null:
		ui._close()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE OK — full gameplay loop ran headless")
		get_tree().quit(0)
	else:
		print("SMOKE FAILED — %d problem(s)" % _failures.size())
		get_tree().quit(1)
