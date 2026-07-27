## A concrete item in the world or an inventory: definition + mutable state.
class_name ItemInstance
extends RefCounted

var def_id: StringName
var count: int = 1
var condition: float = 100.0
var charge: float = 1.0 # 0-1, for batteries/flashlights

func _init(p_def_id: StringName = &"", p_count: int = 1) -> void:
	def_id = p_def_id
	count = p_count
	var d := definition()
	if d != null and d.has_condition:
		condition = d.max_condition

func definition() -> ItemDefinition:
	return ItemDB.get_def(def_id)

func display_name() -> String:
	var d := definition()
	var base := d.display_name if d != null else str(def_id)
	if count > 1:
		return "%s x%d" % [base, count]
	return base

func total_weight() -> float:
	var d := definition()
	if d == null:
		return 0.0
	return d.weight_kg * count

func serialize() -> Dictionary:
	return {"id": str(def_id), "count": count, "condition": condition, "charge": charge}

static func deserialize(data: Dictionary) -> ItemInstance:
	var inst := ItemInstance.new(StringName(data.get("id", "")), int(data.get("count", 1)))
	inst.condition = float(data.get("condition", 100.0))
	inst.charge = float(data.get("charge", 1.0))
	return inst
