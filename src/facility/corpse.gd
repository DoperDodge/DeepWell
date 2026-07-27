## A body. Some are set dressing with pocketable loot; some are YOUR previous
## characters, wearing everything they died carrying (PLAN §16.3, §20.1).
class_name Corpse
extends StaticBody3D

var corpse_id: String
var designation: String = "" # "" = anonymous staff corpse
var loot_table_id: StringName = &"corpse_staff"
var fixed_items: Array = []
var use_fixed: bool = false
var jumpsuit_color: Color = Color(0.7, 0.7, 0.72) # staff grey; Class-D orange

static func create_scripted(id: String, table: StringName, color: Color) -> Corpse:
	var c := Corpse.new()
	c.corpse_id = id
	c.loot_table_id = table
	c.jumpsuit_color = color
	return c

## A previous run's player corpse: their designation, their gear.
static func create_player_remains(record: Dictionary, index: int) -> Corpse:
	var c := Corpse.new()
	c.corpse_id = "player_corpse_%d" % index
	c.designation = record.get("designation", "D-????")
	c.use_fixed = true
	c.fixed_items = record.get("items", [])
	c.jumpsuit_color = Color(0.75, 0.33, 0.08)
	return c

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.22
	mesh.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = jumpsuit_color
	mat.roughness = 0.95
	mesh.material = mat
	body.mesh = mesh
	body.rotation.z = PI * 0.5 # lying down
	body.position.y = 0.22
	add_child(body)
	var pool := MeshInstance3D.new()
	var pool_mesh := CylinderMesh.new()
	pool_mesh.top_radius = 0.65
	pool_mesh.bottom_radius = 0.65
	pool_mesh.height = 0.01
	var pool_mat := StandardMaterial3D.new()
	pool_mat.albedo_color = Color(0.25, 0.02, 0.02)
	pool_mat.roughness = 0.2
	pool_mesh.material = pool_mat
	pool.mesh = pool_mesh
	pool.position.y = 0.005
	add_child(pool)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.5, 0.8)
	shape.shape = box
	shape.position.y = 0.25
	add_child(shape)

func _title() -> String:
	if designation != "":
		return "the body of %s" % designation
	return "the body"

func get_prompt(_player: Node) -> String:
	if FacilityState.opened_containers.has(corpse_id):
		return "[E] Open %s's effects" % designation if designation != "" else "[E] Search again"
	return "[E] (hold) Search %s" % _title()

func interact_duration() -> float:
	return 0.0 if FacilityState.opened_containers.has(corpse_id) else 2.5

func interact(player: Node) -> void:
	if not FacilityState.opened_containers.has(corpse_id):
		FacilityState.opened_containers[corpse_id] = true
		var items := []
		if use_fixed:
			items = fixed_items.duplicate()
		else:
			var table := LootDB.get_table(loot_table_id)
			if table != null:
				for inst in table.roll(corpse_id):
					items.append(inst.serialize())
		FacilityState.container_contents[corpse_id] = items
		if designation != "":
			EventBus.toast.emit("It's %s. You know what happened here." % designation)
			player.sanity.adjust(-6.0) # finding your own predecessor costs something
	get_tree().call_group(&"game_ui", "open_container", self)

# Container-compatible API for the transfer UI.
var display_name: String:
	get:
		return _title()

func get_items() -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for d in FacilityState.container_contents.get(corpse_id, []):
		if typeof(d) == TYPE_DICTIONARY:
			var inst := ItemInstance.deserialize(d)
			if inst.definition() != null:
				out.append(inst)
	return out

func set_items(items: Array[ItemInstance]) -> void:
	var arr := []
	for inst in items:
		arr.append(inst.serialize())
	FacilityState.container_contents[corpse_id] = arr
