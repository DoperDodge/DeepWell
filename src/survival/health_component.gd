## Body-part health model (PLAN §10.2): twelve parts, bleeding drains a
## shared blood volume, untreated wounds infect over hours, sepsis kills.
## There is no regenerating health bar anywhere in this game.
class_name HealthComponent
extends Node

signal died(cause: String)

const PART_IDS: Array[StringName] = [
	&"head", &"neck", &"torso_upper", &"torso_lower",
	&"arm_l", &"arm_r", &"hand_l", &"hand_r",
	&"leg_upper_l", &"leg_upper_r", &"leg_lower_l", &"leg_lower_r",
]
const BLEED_LIGHT := 0.4
const BLEED_HEAVY := 1.8
const WOUND_INFECT_RATE_PER_HOUR := 0.8
const SEPSIS_THRESHOLD := 75.0

const PESTILENCE_DURATION_HOURS := 6.0

var parts: Dictionary = {} # StringName -> BodyPart
var blood: float = 100.0
var sickness: float = 0.0  # 0-100, Sick moodle; fed by sepsis/spoiled food
var painkiller_hours: float = 0.0
## SCP-049's disease (PLAN §10.5 track 2): -1 = clean; else hours elapsed.
## No cure but SCP-500. Symptoms escalate silently — diagnose yourself.
var pestilence_hours: float = -1.0
var dead: bool = false

func _ready() -> void:
	for id in PART_IDS:
		parts[id] = BodyPart.new(id)
	TimeManager.register_tick(_tick_1s, 1.0)

func part(id: StringName) -> BodyPart:
	return parts.get(id)

## damage_type: "blunt" | "cut" | "bite" | "fall" | "corrosion" | "instant_death"
func damage(part_id: StringName, damage_type: StringName, amount: float) -> void:
	if dead:
		return
	if damage_type == &"instant_death":
		_die("catastrophic trauma")
		return
	var p: BodyPart = parts.get(part_id, parts[&"torso_upper"])
	p.health = maxf(p.health - amount, 0.0)
	p.pain = clampf(p.pain + amount * 0.8, 0.0, 100.0)
	match damage_type:
		&"cut":
			p.bleeding_rate += BLEED_LIGHT if amount < 18.0 else BLEED_HEAVY
			p.is_bandaged = false
			if amount >= 25.0:
				p.has_deep_wound = true
				p.is_sutured = false
		&"bite":
			p.bleeding_rate += BLEED_LIGHT
			p.infection_level = maxf(p.infection_level, 15.0)
			p.is_bandaged = false
		&"fall", &"blunt":
			if amount >= 22.0 and _is_limb(part_id) and RNG.stream(&"injury").randf() < 0.55:
				p.is_fractured = true
				p.is_splinted = false
		&"corrosion":
			p.bleeding_rate += BLEED_LIGHT
			p.infection_level = maxf(p.infection_level, 30.0)
	EventBus.body_part_damaged.emit(part_id, damage_type, amount)
	EventBus.player_health_changed.emit(overall_health())
	if p.health <= 0.0 and (part_id == &"head" or part_id == &"neck"):
		_die("cranial trauma")

## Treatments auto-target the worst applicable part — usable under pressure.
func apply_treatment(kind: String, power: float) -> bool:
	# Training matters: a medic's bandage is not your bandage (PLAN §10.7).
	var host := get_parent()
	if host != null and "skills" in host:
		power *= 1.0 + 0.08 * host.skills.level(&"first_aid")
		host.skills.add_xp(&"first_aid", 25.0)
	if GameState.occupation == &"medic":
		power *= 1.3
	match kind:
		"bandage":
			var target := _worst_part(func(p: BodyPart) -> float: return p.bleeding_rate)
			if target == null:
				return false
			target.bleeding_rate = maxf(target.bleeding_rate - BLEED_HEAVY * power, 0.0)
			if target.has_deep_wound and not target.is_sutured:
				# Deep wounds reopen; a bandage only slows them (§10.2).
				target.bleeding_rate = maxf(target.bleeding_rate, BLEED_LIGHT * 0.5)
			target.is_bandaged = true
			EventBus.body_part_treated.emit(target.part_id, &"bandage")
			return true
		"suture":
			var target := _first_part(func(p: BodyPart) -> bool: return p.has_deep_wound and not p.is_sutured)
			if target == null:
				return false
			target.is_sutured = true
			target.bleeding_rate = 0.0
			target.pain += 15.0
			EventBus.body_part_treated.emit(target.part_id, &"suture")
			return true
		"splint":
			var target := _first_part(func(p: BodyPart) -> bool: return p.is_fractured and not p.is_splinted)
			if target == null:
				return false
			target.is_splinted = true
			EventBus.body_part_treated.emit(target.part_id, &"splint")
			return true
		"disinfect":
			var target := _worst_part(func(p: BodyPart) -> float: return p.infection_level)
			if target == null:
				return false
			target.infection_level = maxf(target.infection_level - 45.0 * power, 0.0)
			target.pain += 6.0
			EventBus.body_part_treated.emit(target.part_id, &"disinfect")
			return true
		"painkiller":
			painkiller_hours = 3.0
			EventBus.body_part_treated.emit(&"torso_upper", &"painkiller")
			return true
		"panacea":
			pestilence_hours = -1.0
			# SCP-500. Cures everything, instantly. 1-2 exist per run.
			for id in parts:
				var p: BodyPart = parts[id]
				p.health = 100.0
				p.bleeding_rate = 0.0
				p.pain = 0.0
				p.is_fractured = false
				p.has_deep_wound = false
				p.infection_level = 0.0
			blood = 100.0
			sickness = 0.0
			EventBus.body_part_treated.emit(&"torso_upper", &"panacea")
			return true
	return false

func add_sickness(amount: float) -> void:
	sickness = clampf(sickness + amount, 0.0, 100.0)

func contract_pestilence() -> void:
	if pestilence_hours < 0.0:
		pestilence_hours = 0.0
		# Stage 1 is a slight fever. The player may not realize (§10.5).

func has_pestilence() -> bool:
	return pestilence_hours >= 0.0

## 0-100 progression value for the Feverish moodle.
func pestilence_progress() -> float:
	if pestilence_hours < 0.0:
		return 0.0
	return clampf(pestilence_hours / PESTILENCE_DURATION_HOURS * 100.0, 0.0, 100.0)

func total_bleeding() -> float:
	var b := 0.0
	for id in parts:
		b += parts[id].bleeding_rate
	return b

func total_pain() -> float:
	var pain := 0.0
	for id in parts:
		pain = maxf(pain, parts[id].pain)
	if painkiller_hours > 0.0:
		pain *= 0.3
	return pain

func worst_infection() -> float:
	var v := 0.0
	for id in parts:
		v = maxf(v, parts[id].infection_level)
	return v

func overall_health() -> float:
	var t := 0.0
	for id in parts:
		t += parts[id].health
	return t / parts.size()

## Movement multiplier from leg state: fractures halve speed (PLAN §23).
func leg_mobility() -> float:
	var m := 1.0
	for id in [&"leg_upper_l", &"leg_upper_r", &"leg_lower_l", &"leg_lower_r"]:
		var p: BodyPart = parts[id]
		if p.is_fractured:
			m = minf(m, 0.75 if p.is_splinted else 0.5)
		elif p.health < 40.0:
			m = minf(m, 0.85)
	return m

func hand_steadiness() -> float:
	var m := 1.0
	for id in [&"arm_l", &"arm_r", &"hand_l", &"hand_r"]:
		if parts[id].health < 50.0 or parts[id].is_fractured:
			m -= 0.2
	return clampf(m, 0.3, 1.0)

func _tick_1s() -> void:
	if dead:
		return
	var bleed := total_bleeding()
	if bleed > 0.0:
		blood = maxf(blood - bleed * 0.12, 0.0)
		if blood <= 0.0:
			_die("exsanguination")
			return
	var hours := 1.0 / TimeManager.GAME_HOUR_REAL_SECONDS
	painkiller_hours = maxf(painkiller_hours - hours, 0.0)
	for id in parts:
		var p: BodyPart = parts[id]
		# Wound infection (§10.5 track 1): untreated wounds fester. Dirty
		# bandages are slower than clean treatment but faster than nothing.
		if p.is_wounded() and p.infection_level < 100.0:
			var rate := WOUND_INFECT_RATE_PER_HOUR
			if p.is_bandaged:
				rate *= 0.35
			if not (p.bleeding_rate > 0.0 or p.has_deep_wound or p.infection_level > 0.0):
				rate = 0.0
			p.infection_level = clampf(p.infection_level + rate * hours * 100.0 * 0.01, 0.0, 100.0)
		# Slow natural healing for minor damage only.
		if p.health < 100.0 and p.infection_level < 30.0 and not p.has_deep_wound:
			p.health = minf(p.health + 0.6 * hours, 100.0)
		p.pain = maxf(p.pain - 0.05, 0.0)
	if pestilence_hours >= 0.0:
		var mult := 0.75 if GameState.occupation == &"chemist" else 1.0
		pestilence_hours += hours * mult
		var progress := pestilence_progress()
		if progress > 33.0:
			sickness = maxf(sickness, (progress - 33.0) * 1.2)
		if progress > 66.0 and RNG.stream(&"pestilence").randf() < 0.04:
			# Stage 3: uncontrollable coughing — LOUD (§10.5). 939 isn't here
			# yet, but everything that hunts by sound is listening.
			var host := get_parent() as Node3D
			if host != null and host.is_inside_tree():
				AudioManager.play_3d(&"cough", host.global_position, -4.0)
				EventBus.noise_emitted.emit(host.global_position, 0.35, host, ["cough", "human"])
		if pestilence_hours >= PESTILENCE_DURATION_HOURS:
			_die("the Pestilence")
			return
	var infection := worst_infection()
	if infection > SEPSIS_THRESHOLD:
		add_sickness(0.05)
		if sickness >= 100.0:
			_die("septicemia")
			return
	elif sickness > 0.0:
		sickness = maxf(sickness - 0.02, 0.0)
	blood = minf(blood + 0.01, 100.0)

func _die(cause: String) -> void:
	if dead:
		return
	dead = true
	died.emit(cause)

func _is_limb(id: StringName) -> bool:
	return str(id).begins_with("arm") or str(id).begins_with("leg") or str(id).begins_with("hand")

func _worst_part(metric: Callable) -> BodyPart:
	var best: BodyPart = null
	var best_v := 0.0
	for id in parts:
		var v: float = metric.call(parts[id])
		if v > best_v:
			best_v = v
			best = parts[id]
	return best

func _first_part(pred: Callable) -> BodyPart:
	for id in PART_IDS:
		if pred.call(parts[id]):
			return parts[id]
	return null

func serialize() -> Dictionary:
	var ps := {}
	for id in parts:
		ps[str(id)] = parts[id].serialize()
	return {"blood": blood, "sickness": sickness, "painkiller": painkiller_hours, "pestilence": pestilence_hours, "parts": ps}

func deserialize(d: Dictionary) -> void:
	blood = float(d.get("blood", 100.0))
	sickness = float(d.get("sickness", 0.0))
	painkiller_hours = float(d.get("painkiller", 0.0))
	pestilence_hours = float(d.get("pestilence", -1.0))
	var ps: Dictionary = d.get("parts", {})
	for id in parts:
		if ps.has(str(id)):
			parts[id].apply(ps[str(id)])
