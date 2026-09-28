@tool
class_name ActionDependency
extends Resource

## The ID of the node (ActionNode.id) from the SAME ActionSet whose event we are waiting for.
@export var node_id: String = ""

## The name of that node's event. "finished" means the node has fully completed
## (always available for any action). Any other name corresponds to what
## the node's action declared via get_available_events() and emits
## itself during run().
@export var event: String = "finished"


func get_summary() -> String:
	return "%s:%s" % [node_id, event]
