## Loads data/documents/*.json — every document is authored at full Level-5
## detail with clearance-tagged spans; the viewer redacts down to what the
## player holds (PLAN §8.1). Story gating and keycard gating are one axis.
class_name DocumentDB
extends RefCounted

const DIR := "res://data/documents"

static var _docs: Dictionary = {} # StringName -> Dictionary
static var _loaded := false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_error("DocumentDB: cannot open " + DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			var f := FileAccess.open(DIR + "/" + fname, FileAccess.READ)
			if f != null:
				var parsed: Variant = JSON.parse_string(f.get_as_text())
				if typeof(parsed) == TYPE_DICTIONARY and parsed.has("id"):
					_docs[StringName(parsed.id)] = parsed
				else:
					push_error("DocumentDB: bad document json: " + fname)
		fname = dir.get_next()

static func get_doc(id: StringName) -> Dictionary:
	_ensure()
	return _docs.get(id, {})

static func all_ids() -> Array:
	_ensure()
	return _docs.keys()

static func docs_for_floor(floor_index: int) -> Array:
	_ensure()
	var out := []
	for id in _docs:
		if int(_docs[id].get("found_on_floor", -1)) == floor_index:
			out.append(id)
	out.sort()
	return out

## True if the document contains spans the given clearance still can't read.
static func has_redactions_at(id: StringName, clearance: int) -> bool:
	var doc := get_doc(id)
	for span in doc.get("body", []):
		if int(span.get("clearance", 0)) > clearance:
			return true
	return false
