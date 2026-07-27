## A readable document in the world. Reading is the primary boredom cure and
## the whole lore delivery system (PLAN §8). Collected into the journal;
## re-readable there as clearance rises (progressive declassification).
class_name DocumentPickup
extends StaticBody3D

var pickup_id: String
var document_id: StringName

static func create(id: String, doc_id: StringName) -> DocumentPickup:
	var p := DocumentPickup.new()
	p.pickup_id = id
	p.document_id = doc_id
	return p

func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.21, 0.006, 0.297)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88, 0.87, 0.8)
	mat.roughness = 0.95
	mesh.material = mat
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.15, 0.35)
	shape.shape = box
	add_child(shape)

func get_prompt(_player: Node) -> String:
	var doc := DocumentDB.get_doc(document_id)
	var title: String = doc.get("title", "document") if not doc.is_empty() else "document"
	return "[E] Read \"%s\"" % title

func interact(_player: Node) -> void:
	FacilityState.removed_pickups[pickup_id] = true
	AudioManager.play_3d(&"paper", global_position, -10.0)
	EventBus.document_collected.emit(document_id)
	EventBus.document_open_requested.emit(document_id)
	queue_free()
