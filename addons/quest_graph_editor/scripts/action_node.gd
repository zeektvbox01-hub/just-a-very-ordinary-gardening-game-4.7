@tool
class_name ActionNode
extends Resource

## A single action graph node within a stage.
##
## Without depends_on — the node starts as soon as the stage begins,
## in parallel with all other such nodes (this is identical to the old
## ActionSet behavior: "apply everything at once").
##
## depends_on — a list of ActionDependency: exactly WHICH node and WHICH
## specific event ("finished" or a custom one from action.get_available_events())
## to wait for before this node starts.
##
## delay — a pause in seconds AFTER depends_on are fulfilled,
## before the node actually starts.
##
## Example a/b/c/d ("a waits for b, b and c in parallel, d with a delay"):
##   node_b:  id="b", depends_on=[]
##   node_c:  id="c", depends_on=[]                         # b and c start together
##   node_a:  id="a", depends_on=[{node_id="b", event="finished"}]   # a waits for b to finish
##   node_d:  id="d", depends_on=[], delay=3.0                 # d starts immediately,
##                                                             # but executes after 3s
##
## An event other than "finished" is useful when a should react not to the
## complete termination of b, but to a specific moment inside it, for example
## {node_id="b", event="midpoint"} — if node b's Action declares and
## emits such an event itself.

## Unique (within a single ActionSet) node ID. Mandatory if someone
## references this node via depends_on.
@export var id: String = ""

## What is applied when the node starts.
@export var action: Action

## Which events of which nodes in this same graph must be completed first.
@export var depends_on: Array[ActionDependency] = []

## Pause in seconds after fulfilling depends_on, before starting action.run().
@export_range(0.0, 60.0, 0.1, "or_greater") var delay: float = 0.0

## Editor only: node position in the stage action graph's GraphEdit.
@export var editor_graph_position: Vector2 = Vector2.ZERO


func get_summary() -> String:
	var s := action.get_summary() if action else "(no action)"
	if not depends_on.is_empty():
		var deps: Array[String] = []
		for d in depends_on:
			deps.append(d.get_summary())
		s += " | after: %s" % ", ".join(deps)
	if delay > 0.0:
		s += " | +%.1fs" % delay
	return s
