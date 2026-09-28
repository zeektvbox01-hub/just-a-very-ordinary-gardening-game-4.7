@tool
class_name ActionSet
extends Resource

## Action graph for a single stage. Each node has its own id, its own Action,
## depends_on (a list of ActionDependency: whose node + WHICH specific event
## to wait for), and delay (a pause after the event is received). Nodes
## without depends_on start immediately and in parallel.
@export var nodes: Array[ActionNode] = []

## Emitted when ALL nodes in the graph have completed (every node fired the "finished" event).
signal all_finished


## Runs the graph. host is a SceneTree Node (usually QuestManager).
func apply_all(host: Node) -> void:
	if nodes.is_empty():
		all_finished.emit()
		return
	_GraphRun.new(self, host)


func get_summary() -> String:
	return "%d act." % nodes.size()


static func _run_meta_key(run_instance_id: int) -> String:
	var s := str(run_instance_id)
	if s.begins_with("-"):
		s = "n" + s.substr(1)
	return "_active_run_%s" % s
	
	
func stage_ended() -> void:
	for node in nodes:
		if node.action != null and node.action.scope == node.action.Scope.STAGE_LOCAL:
			node.action.end()

func quest_ended() -> void:
	for node in nodes:
		if node.action != null and node.action.scope == Action.Scope.QUEST_LOCAL:
			node.action.end()

class _GraphRun:
	extends RefCounted

	var _owner: ActionSet
	var _host: Node
	var _fired: Dictionary = {}
	var _started: Dictionary = {}
	var _callbacks: Dictionary = {}
	var _remaining: int
	var _meta_key: String


	func _init(owner: ActionSet, host: Node) -> void:
		_owner = owner
		_host = host
		_remaining = owner.nodes.size()
		_meta_key = ActionSet._run_meta_key(get_instance_id())
		owner.set_meta(_meta_key, self)

		for node in owner.nodes:
			_try_start(node)


	func _key(node: ActionNode) -> String:
		return node.id if node.id != "" else ("__anon_%d" % node.get_instance_id())


	func _has_fired(node_id: String, event_name: String) -> bool:
		return _fired.has(node_id) and _fired[node_id].has(event_name)


	func _try_start(node: ActionNode) -> void:
		var key := _key(node)
		if _started.has(key):
			return
		for dep in node.depends_on:
			if not _has_fired(dep.node_id, dep.event):
				return
		_started[key] = true
		_start_node(node)


	func _start_node(node: ActionNode) -> void:
		if node.delay > 0.0:
			if _host == null or not _host.is_inside_tree():
				push_warning("ActionSet: node '%s' has a delay, but host is not inside tree — delay skipped." % _key(node))
			else:
				await _host.get_tree().create_timer(node.delay).timeout
		_run_action(node)


	func _run_action(node: ActionNode) -> void:
		if node.action == null:
			_on_event("finished", node)
			return
		var cb := _on_event.bind(node)
		_callbacks[_key(node)] = cb
		node.action.event_fired.connect(cb)
		node.action.run(_host)


	func _on_event(event_name: String, node: ActionNode) -> void:
		var key := _key(node)
		if not _fired.has(key):
			_fired[key] = {}
		if _fired[key].has(event_name):
			return
		_fired[key][event_name] = true

		for other in _owner.nodes:
			_try_start(other)

		if event_name != "finished":
			return

		_remaining -= 1
		if _callbacks.has(key):
			if node.action != null:
				node.action.event_fired.disconnect(_callbacks[key])
			_callbacks.erase(key)

		if _remaining <= 0:
			_owner.all_finished.emit()
			_owner.remove_meta(_meta_key)
