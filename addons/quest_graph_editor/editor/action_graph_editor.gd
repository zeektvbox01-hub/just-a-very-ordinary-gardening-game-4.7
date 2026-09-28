@tool
extends Window

const ActionNodeItem = preload("res://addons/quest_graph_editor/editor/action_node_item.gd")
const ActionNode = preload("res://addons/quest_graph_editor/scripts/action_node.gd")
const ActionDependency = preload("res://addons/quest_graph_editor/scripts/action_dependency.gd")

## Emitted upon any graph modification (node added/deleted/modified,
## connection made/broken) — the owner (dock) flags the quest as
## modified ("needs saving").
signal graph_modified

var action_set: ActionSet
var graph: GraphEdit
var status_label: Label

## graph node name -> ActionNodeItem
var _items: Dictionary = {}


func _init() -> void:
	title = "Stage Action Graph"
	size = Vector2i(900, 600)
	visible = false
	close_requested.connect(hide)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	vbox.add_child(toolbar)

	var add_btn := Button.new()
	add_btn.text = "+ New Node"
	add_btn.pressed.connect(_on_add_node)
	toolbar.add_child(add_btn)

	status_label = Label.new()
	toolbar.add_child(status_label)

	graph = GraphEdit.new()
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.right_disconnects = true
	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)
	graph.delete_nodes_request.connect(_on_delete_request)
	vbox.add_child(graph)


## Opens a specific ActionSet graph (usually stage.actions).
func open(p_action_set: ActionSet) -> void:
	action_set = p_action_set
	_rebuild()
	popup_centered_ratio(0.7)


func _rebuild() -> void:
	for child in graph.get_children():
		if child is GraphNode:
			graph.remove_child(child)
			child.free()
	_items.clear()

	if action_set == null:
		return

	for node in action_set.nodes:
		_add_item(node)

	_update_status()

	# Connections can only be made when all GraphNodes are actually inside the tree
	# (otherwise connect_node might not find the ports) — same as in quest_graph_dock.
	await get_tree().process_frame
	_rebuild_connections()


func _update_status() -> void:
	status_label.text = ("Nodes: %d — drag connections FROM LEFT TO RIGHT from event " +
		"ports: A[event] -> B means \"B waits for this event from A\"") % action_set.nodes.size()


func _add_item(node: ActionNode) -> ActionNodeItem:
	var item := ActionNodeItem.new()
	item.setup(node)
	item.modified.connect(_on_item_modified)
	item.id_renamed.connect(_on_item_id_renamed)
	item.delete_requested.connect(_on_item_delete_requested)
	item.ports_changed.connect(_on_item_ports_changed)
	graph.add_child(item)
	_items[item.name] = item
	return item


## Restores graph connections from depends_on. from_item.slot_for_event()
## returns the PORT INDEX (0-based among the node's output ports), which
## connect_node expects as from_port — see action_node_item.gd.
func _rebuild_connections() -> void:
	for to_name in _items.keys():
		var to_item: ActionNodeItem = _items[to_name]
		for dep in to_item.action_node.depends_on:
			var from_item := _find_item_by_id(dep.node_id)
			if from_item == null:
				continue
			var slot := from_item.slot_for_event(dep.event)
			if slot != -1:
				graph.connect_node(from_item.name, slot, to_item.name, 0)


func _find_item_by_id(id: String) -> ActionNodeItem:
	if id == "":
		return null
	for item_name in _items.keys():
		var item: ActionNodeItem = _items[item_name]
		if item.action_node.id == id:
			return item
	return null


func _has_dependency(node: ActionNode, node_id: String, event_name: String) -> bool:
	for dep in node.depends_on:
		if dep.node_id == node_id and dep.event == event_name:
			return true
	return false


func _on_add_node() -> void:
	var node := ActionNode.new()
	node.id = "node_%d" % action_set.nodes.size()
	node.editor_graph_position = Vector2(action_set.nodes.size() * 40, action_set.nodes.size() * 40)
	action_set.nodes.append(node)
	_add_item(node)
	_update_status()
	graph_modified.emit()


func _on_item_modified() -> void:
	graph_modified.emit()


func _on_item_ports_changed() -> void:
	# The node's set of events may have changed (action was switched) — old connections
	# drawn according to previous port indices might "drift" visually.
	# We leave the data (ActionDependency by id+event) untouched — just
	# redraw whatever can still be built from them.
	graph.clear_connections()
	_rebuild_connections()
	graph_modified.emit()


func _on_item_id_renamed(old_id: String, new_id: String) -> void:
	if old_id == new_id:
		return
	for item_name in _items.keys():
		var item: ActionNodeItem = _items[item_name]
		for dep in item.action_node.depends_on:
			if dep.node_id == old_id:
				dep.node_id = new_id
	graph_modified.emit()


func _on_item_delete_requested(item: ActionNodeItem) -> void:
	action_set.nodes.erase(item.action_node)
	if item.action_node.id != "":
		for other_name in _items.keys():
			var other: ActionNodeItem = _items[other_name]
			for i in range(other.action_node.depends_on.size() - 1, -1, -1):
				if other.action_node.depends_on[i].node_id == item.action_node.id:
					other.action_node.depends_on.remove_at(i)
	_items.erase(item.name)
	graph.remove_child(item)
	item.free()
	_update_status()
	graph_modified.emit()


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_item: ActionNodeItem = _items.get(from_node)
	var to_item: ActionNodeItem = _items.get(to_node)
	if from_item == null or to_item == null or from_item == to_item:
		return

	var event_name := from_item.event_name_for_slot(from_port)

	if event_name == "":
		# Dragged not from an event port (e.g., from an input port) — ignore.
		return

	if from_item.action_node.id == "":
		status_label.text = "⚠ First assign an ID to the source node — you cannot reference an event without an ID"
		status_label.add_theme_color_override("font_color", Color.ORANGE)
		return

	if not _has_dependency(to_item.action_node, from_item.action_node.id, event_name):
		var dep := ActionDependency.new()
		dep.node_id = from_item.action_node.id
		dep.event = event_name
		to_item.action_node.depends_on.append(dep)

	graph.connect_node(from_node, from_port, to_node, to_port)
	graph_modified.emit()


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_item: ActionNodeItem = _items.get(from_node)
	var to_item: ActionNodeItem = _items.get(to_node)
	if from_item != null and to_item != null:
		var event_name := from_item.event_name_for_slot(from_port)
		for i in range(to_item.action_node.depends_on.size() - 1, -1, -1):
			var dep: ActionDependency = to_item.action_node.depends_on[i]
			if dep.node_id == from_item.action_node.id and dep.event == event_name:
				to_item.action_node.depends_on.remove_at(i)
				break
	graph.disconnect_node(from_node, from_port, to_node, to_port)
	graph_modified.emit()


func _on_delete_request(nodes: Array[StringName]) -> void:
	for node_name in nodes:
		var item: ActionNodeItem = _items.get(node_name)
		if item:
			_on_item_delete_requested(item)


## Transfers current graph node positions back to ActionNode.editor_graph_position.
## Called before saving the quest (see quest_graph_dock._on_save_all).
func sync_positions_to_resource() -> void:
	for item_name in _items.keys():
		var item: ActionNodeItem = _items[item_name]
		item.sync_position_to_resource()
