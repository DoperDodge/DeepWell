## Spatial truth for one floor: a grid of 4 m cells (PLAN §6.3) carrying
## walkability, room ownership, and door topology. Doubles as the medium for
## AI pathfinding AND noise propagation — sound and monsters travel the same
## corridors (PLAN §9.3: navmesh path distance, adapted to the cell graph).
##
## Two A* graphs are maintained:
##  - _nav:  respects closed doors (what a walking anomaly can traverse)
##  - _open: ignores door state (what sound can pass through, attenuated)
class_name FacilityGrid
extends RefCounted

const CELL_SIZE := 4.0
const NOISE_FALLOFF_CONST := 18.0 # meters; exp(-dist / this) (PLAN §23)
const ATTEN_DOOR_CLOSED := 0.40
const ATTEN_BLAST_DOOR := 0.05

enum CellType { SOLID, ROOM, CORRIDOR }

var width: int
var height: int
var cells: PackedInt32Array          # CellType per cell
var room_ids: PackedInt32Array       # room index per cell, -1 = none

## Edge doors: key = _edge_key(a, b) -> {open: bool, blast: bool, id: String}
var doors: Dictionary = {}
## Edge key -> Door node (for entities that can operate doors, e.g. SCP-049).
var door_nodes: Dictionary = {}

var _nav := AStar2D.new()
var _open := AStar2D.new()

func _init(w: int, h: int) -> void:
	width = w
	height = h
	cells = PackedInt32Array()
	cells.resize(w * h)
	room_ids = PackedInt32Array()
	room_ids.resize(w * h)
	room_ids.fill(-1)

# ---------------------------------------------------------------- cells

func idx(c: Vector2i) -> int:
	return c.y * width + c.x

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height

func cell_type(c: Vector2i) -> int:
	return cells[idx(c)] if in_bounds(c) else CellType.SOLID

func set_cell(c: Vector2i, t: int, room_id: int = -1) -> void:
	cells[idx(c)] = t
	room_ids[idx(c)] = room_id

func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and cells[idx(c)] != CellType.SOLID

func room_id_at(c: Vector2i) -> int:
	return room_ids[idx(c)] if in_bounds(c) else -1

func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(
		(c.x - width * 0.5 + 0.5) * CELL_SIZE, 0.0,
		(c.y - height * 0.5 + 0.5) * CELL_SIZE)

func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(p.x / CELL_SIZE + width * 0.5)),
		int(floor(p.z / CELL_SIZE + height * 0.5)))

# ---------------------------------------------------------------- doors

func _edge_key(a: Vector2i, b: Vector2i) -> String:
	var lo := a if (a.y < b.y or (a.y == b.y and a.x <= b.x)) else b
	var hi := b if lo == a else a
	return "%d,%d|%d,%d" % [lo.x, lo.y, hi.x, hi.y]

func add_door(a: Vector2i, b: Vector2i, door_id: String, blast: bool) -> void:
	doors[_edge_key(a, b)] = {"open": false, "blast": blast, "id": door_id}

func has_door(a: Vector2i, b: Vector2i) -> bool:
	return doors.has(_edge_key(a, b))

func register_door_node(a: Vector2i, b: Vector2i, node: Node) -> void:
	door_nodes[_edge_key(a, b)] = node

func door_node(a: Vector2i, b: Vector2i) -> Node:
	return door_nodes.get(_edge_key(a, b))

func is_door_open(a: Vector2i, b: Vector2i) -> bool:
	var key := _edge_key(a, b)
	return doors.has(key) and doors[key].open

func set_door_open(a: Vector2i, b: Vector2i, open: bool) -> void:
	var key := _edge_key(a, b)
	if not doors.has(key):
		return
	doors[key].open = open
	_sync_nav_edge(a, b)

## Build both A* graphs after carving is complete.
func build_graphs() -> void:
	_nav.clear()
	_open.clear()
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if is_walkable(c):
				var i := idx(c)
				var pos := Vector2(x, y)
				_nav.add_point(i, pos)
				_open.add_point(i, pos)
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if not is_walkable(c):
				continue
			for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = c + offset
				if is_walkable(n) and edge_passable(c, n):
					_open.connect_points(idx(c), idx(n))
					_nav.connect_points(idx(c), idx(n))
					_sync_nav_edge(c, n)

## Two adjacent walkable cells are connected only within the same region
## (same room, or corridor-corridor) or across a door edge. Everything else
## has a wall between it — RoomBuilder erects geometry from this same rule,
## so physics, pathfinding, and noise always agree.
func edge_passable(a: Vector2i, b: Vector2i) -> bool:
	if doors.has(_edge_key(a, b)):
		return true
	return room_id_at(a) == room_id_at(b)

func _sync_nav_edge(a: Vector2i, b: Vector2i) -> void:
	var key := _edge_key(a, b)
	if not doors.has(key):
		return
	var ia := idx(a)
	var ib := idx(b)
	if doors[key].open:
		if not _nav.are_points_connected(ia, ib):
			_nav.connect_points(ia, ib)
	else:
		if _nav.are_points_connected(ia, ib):
			_nav.disconnect_points(ia, ib)

# ---------------------------------------------------------------- queries

## Path an entity can actually walk (closed doors block). Array[Vector2i].
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return _path_on(_nav, from, to)

## Path ignoring door state (for noise, reachability-with-keys checks).
func find_path_open(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	return _path_on(_open, from, to)

func _path_on(graph: AStar2D, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not is_walkable(from) or not is_walkable(to):
		return out
	if not graph.has_point(idx(from)) or not graph.has_point(idx(to)):
		return out
	var pts := graph.get_point_path(idx(from), idx(to))
	for p in pts:
		out.append(Vector2i(int(p.x), int(p.y)))
	return out

## Effective loudness at a listener (PLAN §9.3): path distance with
## exponential falloff and per-door attenuation. A gunshot two rooms away
## through a closed door is quieter than a footstep in the same room.
func effective_loudness(loudness: float, from_pos: Vector3, to_pos: Vector3) -> float:
	var from := world_to_cell(from_pos)
	var to := world_to_cell(to_pos)
	if from == to:
		return loudness * exp(-from_pos.distance_to(to_pos) / NOISE_FALLOFF_CONST)
	var path := find_path_open(from, to)
	if path.is_empty():
		# No connected path at all — treat as heavily muffled straight line.
		return loudness * exp(-from_pos.distance_to(to_pos) / (NOISE_FALLOFF_CONST * 0.35))
	var dist := float(path.size() - 1) * CELL_SIZE
	var atten := 1.0
	for i in range(path.size() - 1):
		var key := _edge_key(path[i], path[i + 1])
		if doors.has(key) and not doors[key].open:
			atten *= ATTEN_BLAST_DOOR if doors[key].blast else ATTEN_DOOR_CLOSED
	return loudness * exp(-dist / NOISE_FALLOFF_CONST) * atten

## Straight-line unobstructed-by-layout check on the grid (cheap LOS).
func grid_line_clear(from: Vector2i, to: Vector2i) -> bool:
	var d := to - from
	var steps := maxi(absi(d.x), absi(d.y))
	if steps == 0:
		return true
	for i in steps + 1:
		var t := float(i) / steps
		var c := Vector2i(roundi(lerpf(from.x, to.x, t)), roundi(lerpf(from.y, to.y, t)))
		if not is_walkable(c):
			return false
	return true

func random_walkable_cell(rng: RandomNumberGenerator) -> Vector2i:
	for _attempt in 200:
		var c := Vector2i(rng.randi_range(0, width - 1), rng.randi_range(0, height - 1))
		if is_walkable(c):
			return c
	for y in height:
		for x in width:
			if is_walkable(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i.ZERO
