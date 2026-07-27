## A searchable world container (PLAN §10.9): desks, lockers, cabinets,
## crates. Searching takes time, roots you in place, and is audible. Loot is
## rolled deterministically from (run seed, container id) on first open and
## persisted in FacilityState.
class_name WorldContainer
extends StaticBody3D

var container_id: String
var display_name: String = "container"
var loot_table_id: StringName = &"generic"
var search_time: float = 2.0
## Fixed contents override (corpse gear, scripted caches). If non-null it is
## used instead of a loot roll on first open.
var fixed_contents: Array = []
var use_fixed: bool = false

func configure(id: String, p_name: String, table: StringName, p_search_time: float = 2.0) -> void:
	container_id = id
	display_name = p_name
	loot_table_id = table
	search_time = p_search_time

func configure_fixed(id: String, p_name: String, contents: Array, p_search_time: float = 2.5) -> void:
	container_id = id
	display_name = p_name
	use_fixed = true
	fixed_contents = contents
	search_time = p_search_time

func _ready() -> void:
	collision_layer = 4 # interactable
	collision_mask = 0

func is_searched() -> bool:
	return FacilityState.opened_containers.has(container_id)

func get_prompt(_player: Node) -> String:
	if is_searched():
		return "[E] Open %s" % display_name
	return "[E] (hold) Search %s" % display_name

func interact_duration() -> float:
	return 0.0 if is_searched() else search_time

func interact(_player: Node) -> void:
	if not is_searched():
		FacilityState.opened_containers[container_id] = true
		var items: Array = []
		if use_fixed:
			items = fixed_contents.duplicate()
		else:
			var table := LootDB.get_table(loot_table_id)
			if table != null:
				for inst in table.roll(container_id):
					items.append(inst.serialize())
		FacilityState.container_contents[container_id] = items
	AudioManager.play_3d(&"pickup", global_position, -10.0)
	EventBus.ui_screen_changed.emit(&"container")
	# game_ui listens for this and opens the dual-pane transfer screen.
	get_tree().call_group(&"game_ui", "open_container", self)

# --- Inventory-facing API (contents live in FacilityState) ---

func get_items() -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for d in FacilityState.container_contents.get(container_id, []):
		if typeof(d) == TYPE_DICTIONARY:
			var inst := ItemInstance.deserialize(d)
			if inst.definition() != null:
				out.append(inst)
	return out

func set_items(items: Array[ItemInstance]) -> void:
	var arr := []
	for inst in items:
		arr.append(inst.serialize())
	FacilityState.container_contents[container_id] = arr
