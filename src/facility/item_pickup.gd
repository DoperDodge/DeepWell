## A loose item lying in the world. Visuals come from the ItemDefinition's
## primitive shape/color. Removal persists per run via FacilityState.
class_name ItemPickup
extends StaticBody3D

var pickup_id: String
var instance: ItemInstance

static func create(id: String, inst: ItemInstance) -> ItemPickup:
	var p := ItemPickup.new()
	p.pickup_id = id
	p.instance = inst
	return p

func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	var def := instance.definition()
	if def == null:
		queue_free()
		return
	var mesh_instance := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = def.world_color
	mat.roughness = 0.6
	if def.is_keycard():
		mat.emission_enabled = true
		mat.emission = def.world_color * 0.4 # keycards catch the eye
	var mesh: PrimitiveMesh
	match def.world_shape:
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = def.world_size.x * 0.5
			c.bottom_radius = def.world_size.x * 0.5
			c.height = def.world_size.y
			mesh = c
		"sphere":
			var s := SphereMesh.new()
			s.radius = def.world_size.x * 0.5
			s.height = def.world_size.x
			mesh = s
		"card":
			var b := BoxMesh.new()
			b.size = Vector3(0.086, 0.008, 0.054)
			mesh = b
		"paper":
			var b2 := BoxMesh.new()
			b2.size = Vector3(0.21, 0.004, 0.297)
			mesh = b2
		_:
			var box := BoxMesh.new()
			box.size = def.world_size
			mesh = box
	mesh.material = mat
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	# Generous grab volume — tiny keycards must not be pixel hunts.
	box_shape.size = Vector3(
		maxf(def.world_size.x, 0.25), maxf(def.world_size.y, 0.2), maxf(def.world_size.z, 0.25))
	shape.shape = box_shape
	add_child(shape)

func get_prompt(_player: Node) -> String:
	return "[E] Take %s" % instance.display_name()

func interact(player: Node) -> void:
	if player.inventory.add_item(instance):
		FacilityState.removed_pickups[pickup_id] = true
		AudioManager.play_3d(&"pickup", global_position, -8.0)
		queue_free()
