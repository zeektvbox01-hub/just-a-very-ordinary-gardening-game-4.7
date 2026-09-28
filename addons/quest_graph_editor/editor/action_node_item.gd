@tool
class_name ActionNodeItem
extends GraphNode

## Emitted upon any node modification (id/action/delay) — the owner
## flags the graph/quest as modified.
signal modified

## Emitted specifically when the action changes — the set of event ports might
## have changed, the owner must redraw graph connections.
signal ports_changed

## Emitted when an ID is renamed: other nodes whose depends_on
## referenced the old ID must update their reference to the new one.
signal id_renamed(old_id: String, new_id: String)

## Emitted when the "Delete Node" button is pressed.
signal delete_requested(item: ActionNodeItem)

var action_node: ActionNode

## Event port names IN ORDER OF PORT INDEX (not line number).
## The index in this array is precisely what Godot passes as
## from_port/to_port in connection_request and expects in connect_node(): the ordinal
## number AMONG ENABLED ports of that side (internal right_port_cache),
## NOT the row/slot number of the node (which is used in set_slot()). Service
## rows (id, action picker, delay...) do not end up here at all — otherwise
## we would have to mess with an offset based on the number of widgets on top, which
## breaks on any layout change (see the bug history with "+6").
var _event_port_names: Array[String] = []

var _id_edit: LineEdit
var _picker: EditorResourcePicker
var _delay_spin: SpinBox


func setup(p_action_node: ActionNode) -> void:
	action_node = p_action_node
	# GraphEdit stores connections by node name — it MUST NOT depend on the id,
	# otherwise renaming the id will break already drawn connections.
	name = "item_%d" % get_instance_id()
	title = action_node.id if action_node.id != "" else "(no id)"
	position_offset = action_node.editor_graph_position
	resizable = true
	custom_minimum_size = Vector2(240, 0)

	_rebuild_ui()


func _rebuild_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_event_port_names.clear()

	# Slot 0: the single input — "waiting for other nodes' events". Any number
	# of incoming connections can be made to it. This is the only
	# left-enabled slot on the node, so its port index = 0, and to_port=0,
	# hardcoded in quest_graph_editor_window._rebuild_connections(),
	# is always correct without any mapping.
	var in_label := Label.new()
	in_label.text = "◀ dependencies (input)"
	add_child(in_label)
	set_slot(0, true, 0, Color.WHITE, false, 0, Color.WHITE)

	_id_edit = LineEdit.new()
	_id_edit.text = action_node.id
	_id_edit.placeholder_text = "node id (for depends_on)"
	_id_edit.text_changed.connect(_on_id_changed)
	add_child(_id_edit)

	_picker = EditorResourcePicker.new()
	_picker.base_type = "Action"
	_picker.edited_resource = action_node.action
	_picker.resource_changed.connect(_on_action_changed)
	add_child(_picker)

	# EditorResourcePicker technically allows opening the selected resource via
	# its hidden arrow menu ("Edit"), but inside a GraphNode within a custom
	# dock, clicks often don't reach it (GraphNode intercepts the mouse for
	# dragging) — therefore, we duplicate it with an explicit button that guarantees
	# opening specifically the action's PROPERTIES (npc_id, value, etc.) in the inspector.
	var edit_action_btn := Button.new()
	edit_action_btn.text = "✎ Action Properties"
	edit_action_btn.tooltip_text = "Open the selected Action in the inspector to modify its custom fields"
	edit_action_btn.disabled = action_node.action == null
	edit_action_btn.pressed.connect(_on_edit_action_pressed)
	add_child(edit_action_btn)

	var delay_row := HBoxContainer.new()
	var delay_label := Label.new()
	delay_label.text = "Delay (s):"
	delay_row.add_child(delay_label)
	_delay_spin = SpinBox.new()
	_delay_spin.min_value = 0.0
	_delay_spin.max_value = 60.0
	_delay_spin.step = 0.1
	_delay_spin.value = action_node.delay
	_delay_spin.value_changed.connect(_on_delay_changed)
	delay_row.add_child(_delay_spin)
	add_child(delay_row)

	var del_btn := Button.new()
	del_btn.text = "✕ Remove Node"
	del_btn.pressed.connect(func(): delete_requested.emit(self))
	add_child(del_btn)

	add_child(HSeparator.new())

	# One port row for each event that the action can emit:
	# "finished" is always first, followed by whatever action.get_available_events()
	# returns. Each row = a separate SLOT (slot number = child row number, for set_slot),
	# but the PORT INDEX of this event for connect_node is simply its ordinal
	# number among events (0, 1, 2, ...), unrelated to the row number.
	for event_name in _collect_events():
		var row := HBoxContainer.new()
		var lbl := Label.new()
		lbl.text = "%s ▶" % event_name
		row.add_child(lbl)
		add_child(row)
		var slot_idx := get_child_count() - 1
		set_slot(slot_idx, false, 0, Color.WHITE, true, 0, _color_for_event(event_name))
		_event_port_names.append(event_name)


func _collect_events() -> Array[String]:
	var events: Array[String] = ["finished"]
	if action_node.action != null:
		for e in action_node.action.get_available_events():
			if not events.has(e):
				events.append(e)
	return events


func _color_for_event(event_name: String) -> Color:
	if event_name == "finished":
		return Color(0.45, 0.85, 0.45)
	return Color(0.5, 0.7, 1.0)


## Event name for the given port index (0-based among output ports
## of this node), or "" if the index is out of range. idx comes directly
## from the connection_request/disconnection_request signal (from_port) — it
## is ALREADY a port index, not a row number, so it doesn't need to be recalculated.
func event_name_for_slot(idx: int) -> String:
	if idx >= 0 and idx < _event_port_names.size():
		return _event_port_names[idx]
	return ""


## Port index (for connect_node/disconnect_node) for the given event,
## or -1 if the current action does not have such an event (e.g., the action
## was changed and it disappeared).
func slot_for_event(event_name: String) -> int:
	return _event_port_names.find(event_name)


func _on_id_changed(t: String) -> void:
	var old_id := action_node.id
	action_node.id = t
	title = t if t != "" else "(no id)"
	id_renamed.emit(old_id, t)
	modified.emit()


func _on_action_changed(res: Resource) -> void:
	action_node.action = res
	_rebuild_ui()
	modified.emit()
	ports_changed.emit()


## Opens the OWN fields of the action resource (not the ActionNode itself) in
## Godot's standard right-hand Inspector. EditorInterface is a global singleton
## since version 4.2; if you are using Godot < 4.2 and it is unavailable, replace the line
## below with something like "get_owner().plugin.get_editor_interface().edit_resource(...)",
## passing a reference to the plugin just like it's done in quest_graph_dock.gd.
func _on_edit_action_pressed() -> void:
	if action_node.action == null:
		return
	EditorInterface.edit_resource(action_node.action)


func _on_delay_changed(v: float) -> void:
	action_node.delay = v
	modified.emit()


func sync_position_to_resource() -> void:
	action_node.editor_graph_position = position_offset
