## Data definition for one biomonitor moodle (PLAN §10.1).
## Content lives in data/moodles/*.tres.
class_name MoodleDefinition
extends Resource

@export var id: StringName
@export var display_name: String
## Player stat sampled each second (see Player.get_stat for the full list).
@export var stat: StringName
## Stat values at which severity levels 1-4 begin. Ascending.
@export var thresholds: Array[float] = [25.0, 50.0, 75.0, 90.0]
## Severity captions, index 0 = level 1.
@export var labels: Array[String] = ["", "", "", ""]
@export var color: Color = Color(0.9, 0.75, 0.3)
@export_multiline var hint: String = ""

func level_for(value: float) -> int:
	var level := 0
	for t in thresholds:
		if value >= t:
			level += 1
	return level

func label_for(level: int) -> String:
	if level <= 0 or labels.is_empty():
		return ""
	return labels[clampi(level - 1, 0, labels.size() - 1)]
