## Active-use item behaviors (PLAN §4 src/items/behaviors, folded into one
## dispatch table). Returns true if the item was consumed/used.
class_name ItemBehaviors
extends RefCounted

static func use(player: Node, inst: ItemInstance) -> bool:
	var def := inst.definition()
	if def == null:
		return false
	match def.use_behavior:
		"consume":
			return _consume(player, inst, def)
		"medical":
			return _medical(player, inst, def)
		"battery":
			return _battery(player, inst, def)
		"flashlight":
			player.toggle_flashlight()
			return false
		"read":
			var doc_id := StringName(def.behavior_params.get("document_id", ""))
			if doc_id != &"":
				EventBus.document_open_requested.emit(doc_id)
			return false
	return false

static func _consume(player: Node, inst: ItemInstance, def: ItemDefinition) -> bool:
	var needs: Node = player.needs
	needs.adjust(&"hunger", -def.hunger_restore)
	needs.adjust(&"thirst", -def.thirst_restore)
	needs.adjust(&"fatigue", -def.fatigue_restore)
	needs.adjust(&"boredom", -def.boredom_relief)
	if def.sanity_restore != 0.0:
		player.sanity.adjust(def.sanity_restore)
	if def.sickness_risk > 0.0 and RNG.stream(&"consume").randf() < def.sickness_risk:
		player.health.add_sickness(35.0)
		EventBus.toast.emit("That tasted wrong.")
	var sound := &"drink" if def.has_category(&"drink") else &"eat"
	AudioManager.play_3d(sound, player.global_position, -6.0)
	EventBus.noise_emitted.emit(player.global_position, 0.12, player, ["foley"])
	EventBus.item_consumed.emit(def.id)
	GameState.stats.items_used += 1
	inst.count -= 1
	return inst.count <= 0

static func _medical(player: Node, inst: ItemInstance, def: ItemDefinition) -> bool:
	var health: Node = player.health
	var kind: String = def.behavior_params.get("medical_kind", "bandage")
	var power: float = def.behavior_params.get("power", 1.0)
	if not health.apply_treatment(kind, power):
		EventBus.toast.emit("No injury that %s would help." % def.display_name)
		return false
	AudioManager.play_3d(&"bandage", player.global_position, -8.0)
	EventBus.noise_emitted.emit(player.global_position, 0.15, player, ["foley"])
	GameState.stats.items_used += 1
	inst.count -= 1
	return inst.count <= 0

static func _battery(player: Node, inst: ItemInstance, _def: ItemDefinition) -> bool:
	var flashlight: ItemInstance = player.inventory.first_of_category(&"light")
	if flashlight == null:
		EventBus.toast.emit("Nothing to power.")
		return false
	if flashlight.charge > 0.85:
		EventBus.toast.emit("The battery is still good.")
		return false
	flashlight.charge = 1.0
	AudioManager.play_3d(&"pickup", player.global_position, -6.0)
	EventBus.toast.emit("Battery replaced.")
	GameState.stats.items_used += 1
	inst.count -= 1
	return inst.count <= 0
