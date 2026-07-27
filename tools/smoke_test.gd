## Headless gameplay smoke test:
##   godot --headless --path . -- --smoke
## Plays a complete run: intake on Floor 1, descent through all four floors,
## per-floor anomaly checks (966 thermal reveal, 173 hunt-kill on a second
## site visit, 049/049-2 and the Pestilence), SCP-914, saves, the ending,
## and the risen-corpse mechanic. Exit 0 only if the whole arc runs.
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
	var main := get_parent()
	GameState.occupation = &"medic"
	GameState.traits = [&"steady_hands", &"twitchy"]
	main._start_run(424242, true, false)
	await _wait(0.5)

	var player := GameState.player
	_check(player != null, "player did not spawn")
	if player == null:
		return _finish()
	_check(GameState.floor_index == 1, "run did not start on Floor 1")
	_check(player.inventory.has_item(&"bandage"), "medic kit missing")
	_check(player.skills.level(&"first_aid") == 3, "medic First Aid seed missing")
	print("smoke: run started on floor 1 as medic")

	# --- Floor 1: quiet by design (PLAN §6.2) ---
	_check(_count_scps("SCP173") == 0 and _count_scps("SCP966") == 0, "Floor 1 must have no anomalies")
	var effects := _find_container("f1_cont_spawn_effects")
	_check(effects != null, "personal effects locker missing on floor 1")
	if effects != null:
		effects.interact(player)
		for it in effects.get_items():
			player.inventory.add_item(it)
		_close_ui()
	_check(player.inventory.has_item(&"flashlight"), "starter flashlight missing")

	# Door cycle still works.
	var door: Door = null
	for d in get_tree().root.find_children("*", "Door", true, false):
		if d.state == Door.DoorState.UNLOCKED:
			door = d
			break
	_check(door != null, "no unlocked door on floor 1")
	if door != null:
		door.interact(player)
		await _wait(1.0)
		_check(door.state == Door.DoorState.OPEN, "door did not open")

	# --- Descend to Floor 2 ---
	await _descend_with_clearance(1)
	_check(GameState.floor_index == 2, "descent to floor 2 failed")
	_check(GameState.player.inventory.has_item(&"flashlight"), "inventory lost in descent")
	player = GameState.player

	# SCP-966: two of them, invisible until thermal.
	var sleepers := _find_scps("SCP966")
	_check(sleepers.size() == 2, "expected 2 SCP-966, found %d" % sleepers.size())
	if not sleepers.is_empty():
		var sleeper: Node3D = sleepers[0]
		_check(not sleeper._model.visible, "966 must start invisible")
		player.inventory.add_item(ItemInstance.new(&"thermal_goggles"))
		player.toggle_thermal()
		_check(player.thermal_on, "thermal goggles did not engage")
		await _wait(0.3)
		_check(sleeper._model.visible, "966 not revealed under thermal")
		_check(player.gaze.attention_cone_deg < 40.0, "goggles must narrow attention")
		player.toggle_thermal()
		await _wait(0.2)
		_check(not sleeper._model.visible, "966 visible without thermal")
		print("smoke: floor 2 + SCP-966 thermal ok")

	# --- Descend to Floor 3 ---
	await _descend_with_clearance(2)
	_check(GameState.floor_index == 3, "descent to floor 3 failed")
	player = GameState.player
	_check(_count_scps("SCP173") == 1, "SCP-173 missing on floor 3")
	_check(_count_scps("SCP1048") == 1, "SCP-1048 missing on floor 3")

	# SCP-914 upgrades a keycard on Fine.
	var machines := get_tree().root.find_children("*", "SCP914", true, false)
	_check(machines.size() == 1, "expected one SCP-914 on floor 3")
	if machines.size() == 1:
		var machine: SCP914 = machines[0]
		machine.setting_index = 3
		var card := ItemInstance.new(&"keycard_l1")
		player.inventory.add_item(card)
		machine.process_item(player, card)
		await _wait(3.6)
		_check(player.inventory.has_item(&"keycard_l2"), "914 Fine did not upgrade L1 -> L2")
		print("smoke: floor 3 + SCP-914 ok")

	# Save/load fidelity mid-run, on a deep floor.
	SaveManager.save_run()
	var save := SaveManager.read_save()
	_check(int(save.get("floor", -1)) == 3, "save did not record floor 3")
	_check(save.get("occupation", "") == "medic", "save lost occupation")

	# --- Descend to Floor 4 ---
	await _descend_with_clearance(3)
	_check(GameState.floor_index == 4, "descent to floor 4 failed")
	player = GameState.player
	_check(_count_scps("SCP049") == 1, "SCP-049 missing on floor 4")
	_check(_count_scps("SCP049_2") >= 3, "SCP-049-2 pack missing on floor 4")

	# Pestilence: contract, watch the moodle, cure with SCP-500.
	player.health.contract_pestilence()
	player.health.pestilence_hours = 3.0
	_check(player.get_stat(&"feverish") > 40.0, "feverish stat not rising")
	var pill := ItemInstance.new(&"scp_500_pill")
	player.inventory.add_item(pill)
	player.inventory.use_item(pill)
	_check(not player.health.has_pestilence(), "SCP-500 failed to cure the Pestilence")
	print("smoke: floor 4 + Pestilence + SCP-500 ok")

	# 049 opens doors on his rounds.
	var doctor: Node3D = _find_scps("SCP049")[0]
	var any_closed: Door = null
	for d in get_tree().root.find_children("*", "Door", true, false):
		if d.state != Door.DoorState.OPEN and not d.is_blast and d.state != Door.DoorState.WELDED:
			any_closed = d
			break
	if any_closed != null:
		any_closed.force_open_for_entity()
		await _wait(1.0)
		_check(any_closed.state == Door.DoorState.OPEN, "049 door force-open failed")

	# --- The ending: final floor exit ---
	EventBus.descend_requested.emit()
	await _wait(0.8)
	var ui: Node = get_tree().get_first_node_in_group(&"game_ui")
	_check(ui != null and ui.screen == GameUI.Screen.ENDING, "final descent did not roll the ending")
	_check(not GameState.run_active, "run still active after ending")
	print("smoke: ending ok")
	if ui != null:
		ui._close()

	# --- The §20.1 flagship: a pestilent corpse rises on the next visit ---
	FacilityState.record_player_death(4, Vector2i(10, 10), "the Pestilence", [ItemInstance.new(&"crowbar").serialize()], true)
	var dead_designation := GameState.designation
	main._start_run(424242, true, false)
	await _wait(0.4)
	GameState.floor_index = 4
	main._build_world(false, {})
	await _wait(0.5)
	var risen_found := false
	for z in _find_scps("SCP049_2"):
		if z.risen_designation == dead_designation:
			risen_found = true
	_check(risen_found, "pestilent corpse did not rise as 049-2 wearing its designation")
	var corpse_found := false
	for c in get_tree().root.find_children("*", "Corpse", true, false):
		if c.designation == dead_designation:
			corpse_found = true
	_check(corpse_found, "corpse with gear missing beside its risen self")
	print("smoke: risen corpse (PLAN §20.1) ok")

	# --- SCP-173 kill on a fresh site visit (regression) ---
	GameState.floor_index = 3
	main._build_world(false, {})
	await _wait(0.5)
	player = GameState.player
	var statues := _find_scps("SCP173")
	_check(statues.size() == 1, "SCP-173 missing for kill test")
	if statues.size() == 1:
		var statue: Node3D = statues[0]
		var away := (player.global_position - statue.global_position).normalized()
		player.global_position = statue.global_position + away * 6.0
		player.look_at(player.global_position + away, Vector3.UP)
		statue.hunting = true
		var deadline := 12.0
		while deadline > 0.0 and not player.dead:
			deadline -= 0.1
			await _wait(0.1)
		_check(player.dead, "SCP-173 failed to kill an unwatching player")
		print("smoke: 173 kill ok")

	_finish()

## Grant the exit card and use the stairwell, like a player who found it.
func _descend_with_clearance(level: int) -> void:
	var player := GameState.player
	player.inventory.add_item(ItemInstance.new(StringName("keycard_l%d" % level)))
	EventBus.descend_requested.emit()
	await _wait(0.8)

func _find_scps(cls: String) -> Array:
	return get_tree().root.find_children("*", cls, true, false)

func _count_scps(cls: String) -> int:
	return _find_scps(cls).size()

func _find_container(id: String) -> WorldContainer:
	for c in get_tree().root.find_children("*", "WorldContainer", true, false):
		if c.container_id == id:
			return c
	return null

func _close_ui() -> void:
	var ui := get_tree().get_first_node_in_group(&"game_ui")
	if ui != null:
		ui._close()

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE OK — full four-floor run + ending + risen corpse")
		get_tree().quit(0)
	else:
		print("SMOKE FAILED — %d problem(s)" % _failures.size())
		get_tree().quit(1)
