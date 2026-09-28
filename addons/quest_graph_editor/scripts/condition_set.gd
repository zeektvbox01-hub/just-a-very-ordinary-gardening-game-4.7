@tool
class_name ConditionSet
extends Condition

enum Mode { ALL, ANY }

@export var mode: Mode = Mode.ALL
@export var conditions: Array[Condition] = []


func is_met() -> bool:
	if conditions.is_empty():
		return true

	match mode:
		Mode.ALL:
			for c in conditions:
				if not c.is_met():
					return false
			return true
		Mode.ANY:
			for c in conditions:
				if c.is_met():
					return true
			return false
	return true


func get_summary() -> String:
	if conditions.is_empty():
		return "0 conditions"
	var mode_str := "ALL" if mode == Mode.ALL else "ANY"
	return "%d cond. (%s)" % [conditions.size(), mode_str]
