## One of the twelve tracked body parts (PLAN §10.2).
class_name BodyPart
extends RefCounted

var part_id: StringName
var health: float = 100.0
var bleeding_rate: float = 0.0 # HP/sec drained from blood volume
var pain: float = 0.0
var is_fractured: bool = false
var is_splinted: bool = false
var is_bandaged: bool = false
var is_sutured: bool = false
var has_deep_wound: bool = false
var infection_level: float = 0.0 # 0-100 local wound infection

func _init(p_id: StringName = &"") -> void:
	part_id = p_id

func is_wounded() -> bool:
	return bleeding_rate > 0.0 or has_deep_wound or is_fractured or health < 99.0 or infection_level > 5.0

func status_line() -> String:
	var bits: Array[String] = []
	if is_fractured:
		bits.append("SPLINTED FRACTURE" if is_splinted else "FRACTURE")
	if has_deep_wound:
		bits.append("SUTURED WOUND" if is_sutured else "DEEP WOUND")
	if bleeding_rate > 0.0:
		bits.append("BLEEDING (%s)" % ("heavy" if bleeding_rate > 1.0 else "light"))
	if is_bandaged:
		bits.append("bandaged")
	if infection_level > 40.0:
		bits.append("INFECTED")
	elif infection_level > 10.0:
		bits.append("inflamed")
	if bits.is_empty():
		return "intact" if health > 90.0 else "bruised"
	return ", ".join(bits)

func serialize() -> Dictionary:
	return {
		"id": str(part_id), "hp": health, "bleed": bleeding_rate, "pain": pain,
		"fx": is_fractured, "splint": is_splinted, "band": is_bandaged,
		"sut": is_sutured, "deep": has_deep_wound, "inf": infection_level,
	}

func apply(d: Dictionary) -> void:
	health = float(d.get("hp", 100.0))
	bleeding_rate = float(d.get("bleed", 0.0))
	pain = float(d.get("pain", 0.0))
	is_fractured = bool(d.get("fx", false))
	is_splinted = bool(d.get("splint", false))
	is_bandaged = bool(d.get("band", false))
	is_sutured = bool(d.get("sut", false))
	has_deep_wound = bool(d.get("deep", false))
	infection_level = float(d.get("inf", 0.0))
