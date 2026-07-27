## Data definition for every item (PLAN §5.3). Content lives in
## data/items/*.tres — adding an item means adding one .tres, zero code.
class_name ItemDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Physical")
@export var weight_kg: float = 0.5
@export var max_stack: int = 1
## Visual for world pickups: primitive + color (no binary assets — see
## docs/ARCHITECTURE.md). One of: "box", "cylinder", "sphere", "card", "paper".
@export var world_shape: String = "box"
@export var world_color: Color = Color(0.6, 0.6, 0.6)
@export var world_size: Vector3 = Vector3(0.2, 0.15, 0.2)

@export_group("Condition")
@export var has_condition: bool = false
@export var max_condition: float = 100.0
@export var condition_loss_per_use: float = 1.0

@export_group("Behavior")
## Categories: "food","drink","medical","keycard","tool","light","battery",
## "material","document","anomalous"
@export var categories: Array[StringName] = []
## Behavior id resolved by ItemBehaviors: "", "consume", "medical", "battery",
## "flashlight", "read"
@export var use_behavior: String = ""
@export var behavior_params: Dictionary = {}

@export_group("Keycard")
@export var clearance_level: int = -1 # -1 = not a keycard

@export_group("Consumable")
@export var hunger_restore: float = 0.0
@export var thirst_restore: float = 0.0
@export var fatigue_restore: float = 0.0
@export var sanity_restore: float = 0.0
@export var boredom_relief: float = 0.0
@export var sickness_risk: float = 0.0 # 0-1 chance of Sick on use (spoiled food)

@export_group("SCP-914")
@export var upgrade_result: StringName = &""   # produced on "Fine"
@export var refine_result: StringName = &""    # produced on "Very Fine"
@export var downgrade_result: StringName = &"" # produced on "Rough"/"Coarse"

func is_keycard() -> bool:
	return clearance_level >= 0

func has_category(cat: StringName) -> bool:
	return categories.has(cat)
