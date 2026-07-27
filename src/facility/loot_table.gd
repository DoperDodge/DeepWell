## Weighted loot table (PLAN §6.3 step i). Content in data/loot_tables/*.tres.
class_name LootTable
extends Resource

@export var id: StringName
@export var rolls_min: int = 1
@export var rolls_max: int = 3
## Chance a roll produces nothing at all (scarcity is the game).
@export var empty_chance: float = 0.25
## Entries: {"item": StringName, "weight": float, "min": int, "max": int}
@export var entries: Array[Dictionary] = []

## Deterministic per (seed, salt): the same container always holds the same
## loot for a given run seed, regardless of open order.
func roll(salt: String) -> Array[ItemInstance]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(RNG.master_seed()) + "::loot::" + salt)
	var out: Array[ItemInstance] = []
	var abundance: float = GameState.sandbox.get("loot_abundance", 1.0)
	var n := rng.randi_range(rolls_min, rolls_max)
	n = maxi(int(round(n * abundance)), 0)
	var total_weight := 0.0
	for e in entries:
		total_weight += float(e.get("weight", 1.0))
	if total_weight <= 0.0:
		return out
	for _i in n:
		if rng.randf() < empty_chance:
			continue
		var pick := rng.randf() * total_weight
		for e in entries:
			pick -= float(e.get("weight", 1.0))
			if pick <= 0.0:
				var count := rng.randi_range(int(e.get("min", 1)), int(e.get("max", 1)))
				var item_id := StringName(e.get("item", ""))
				if ItemDB.exists(item_id) and count > 0:
					out.append(ItemInstance.new(item_id, count))
				break
	return out
