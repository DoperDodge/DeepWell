## Weight-based inventory (PLAN §10.9). Base capacity 8 + strength * 2 kg.
## Encumbrance tiers: <70% normal, 70-100% slowed/no sprint, >100% severe.
class_name Inventory
extends Node

const ENCUMBER_SLOW := 0.70
const ENCUMBER_SEVERE := 1.00

var items: Array[ItemInstance] = []
var capacity_kg: float = 16.0

func total_weight() -> float:
	var w := 0.0
	for it in items:
		w += it.total_weight()
	return w

## 0 = fine, 1 = slowed (no sprint), 2 = severe (no run, loud)
func encumbrance_tier() -> int:
	var ratio := total_weight() / maxf(capacity_kg, 0.01)
	if ratio > ENCUMBER_SEVERE:
		return 2
	if ratio > ENCUMBER_SLOW:
		return 1
	return 0

func can_fit(inst: ItemInstance) -> bool:
	# Hard cap at 135% — beyond that you physically cannot pick it up.
	return total_weight() + inst.total_weight() <= capacity_kg * 1.35

func add_item(inst: ItemInstance) -> bool:
	if inst == null or inst.definition() == null:
		return false
	if not can_fit(inst):
		EventBus.toast.emit("Too heavy to carry.")
		return false
	var def := inst.definition()
	if def.max_stack > 1:
		for it in items:
			if it.def_id == inst.def_id and it.count < def.max_stack:
				var space := def.max_stack - it.count
				var moved := mini(space, inst.count)
				it.count += moved
				inst.count -= moved
				if inst.count <= 0:
					_after_change(def)
					return true
	items.append(inst)
	_after_change(def)
	return true

func remove_item(inst: ItemInstance) -> void:
	items.erase(inst)
	EventBus.inventory_changed.emit()

func use_item(inst: ItemInstance) -> void:
	var player := get_parent()
	if ItemBehaviors.use(player, inst):
		items.erase(inst)
	EventBus.inventory_changed.emit()

func first_of_category(cat: StringName) -> ItemInstance:
	for it in items:
		var d := it.definition()
		if d != null and d.has_category(cat):
			return it
	return null

func has_item(id: StringName) -> bool:
	for it in items:
		if it.def_id == id:
			return true
	return false

func count_of(id: StringName) -> int:
	var n := 0
	for it in items:
		if it.def_id == id:
			n += it.count
	return n

func consume_one(id: StringName) -> bool:
	for it in items:
		if it.def_id == id:
			it.count -= 1
			if it.count <= 0:
				items.erase(it)
			EventBus.inventory_changed.emit()
			return true
	return false

func best_keycard_level() -> int:
	var best := 0
	for it in items:
		var d := it.definition()
		if d != null and d.is_keycard():
			best = maxi(best, d.clearance_level)
	return best

func serialize() -> Array:
	var out := []
	for it in items:
		out.append(it.serialize())
	return out

func deserialize(data: Array) -> void:
	items.clear()
	for d in data:
		if typeof(d) == TYPE_DICTIONARY:
			var inst := ItemInstance.deserialize(d)
			if inst.definition() != null:
				items.append(inst)
	EventBus.inventory_changed.emit()

func _after_change(def: ItemDefinition) -> void:
	if def.is_keycard():
		EventBus.keycard_acquired.emit(def.clearance_level)
	EventBus.item_picked_up.emit(def.id)
	EventBus.inventory_changed.emit()
