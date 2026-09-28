@tool
@abstract class_name Action
extends SmartResource

enum Scope {
	STAGE_LOCAL,
	QUEST_LOCAL,
	PERSISTENT,
}

## Determines the scope of the action's lifecycle/execution.
@export var scope: Scope = Scope.STAGE_LOCAL

signal event_fired(name: String)

func apply() -> void:
	pass

func run(_host: Node) -> void:
	apply()
	event_fired.emit("finished")

func end() -> void:
	_on_ended()
	
func _on_ended() -> void:
	pass

func get_available_events() -> PackedStringArray:
	return PackedStringArray()

func get_summary() -> String:
	return "Action"
