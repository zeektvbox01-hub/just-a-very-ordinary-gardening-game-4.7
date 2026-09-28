@tool
extends Control

const QuestGraphNode = preload("res://addons/quest_graph_editor/editor/quest_graph_node.gd")
const Quest = preload("res://addons/quest_graph_editor/scripts/quest.gd")

const QUEST_DIR := "res://data/quests/"

var plugin: EditorPlugin
var graph: GraphEdit
var status_label: Label
var action_graph_editor: Window

## quest.id -> QuestGraphNode
var quest_nodes: Dictionary = {}
## quest.id -> Quest (for quick lookup when rebuilding connections)
var quests_by_id: Dictionary = {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	vbox.add_child(toolbar)

	var new_btn := Button.new()
	new_btn.text = "+ New Quest"
	new_btn.pressed.connect(_on_new_quest)
	toolbar.add_child(new_btn)

	var save_btn := Button.new()
	save_btn.text = "Save All"
	save_btn.pressed.connect(_on_save_all)
	toolbar.add_child(save_btn)

	var reload_btn := Button.new()
	reload_btn.text = "Reload"
	reload_btn.pressed.connect(_reload_graph)
	toolbar.add_child(reload_btn)

	status_label = Label.new()
	status_label.text = "Data folder: " + QUEST_DIR
	toolbar.add_child(status_label)

	graph = GraphEdit.new()
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	graph.right_disconnects = true
	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)
	graph.delete_nodes_request.connect(_on_delete_request)
	vbox.add_child(graph)


func _ready() -> void:
	await get_tree().process_frame
	print("[QuestGraph] dock rect=", get_rect(), " visible=", visible)
	print("[QuestGraph] graph rect=", graph.get_rect(), " visible=", graph.visible, " in_tree=", graph.is_inside_tree())
	_reload_graph()


func _reload_graph() -> void:
	# GraphEdit.get_children() always includes the internal service node
	# "_connection_layer" — if freed along with the rest, the graph
	# stops rendering connections and nodes entirely (error "connections_layer is missing").
	# Therefore, we only clear actual GraphNodes.
	for child in graph.get_children():
		if child is GraphNode:
			graph.remove_child(child)
			child.free()
	quest_nodes.clear()
	quests_by_id.clear()

	if not DirAccess.dir_exists_absolute(QUEST_DIR):
		DirAccess.make_dir_recursive_absolute(QUEST_DIR)

	var dir := DirAccess.open(QUEST_DIR)
	if dir == null:
		return

	var quests: Array[Quest] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res := load(QUEST_DIR + file_name)
			if res is Quest:
				quests.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()

	for q in quests:
		quests_by_id[q.id] = q

	for q in quests:
		_add_quest_node(q)

	# Restore graph connections from sub_quests after all nodes are created.
	await get_tree().process_frame
	for q in quests:
		for sub in q.sub_quests:
			if quest_nodes.has(q.id) and quest_nodes.has(sub.id):
				graph.connect_node(quest_nodes[q.id].name, 0, quest_nodes[sub.id].name, 0)

	status_label.text = "Loaded quests: %d" % quests.size()


func _add_quest_node(q: Quest) -> void:
	var node := QuestGraphNode.new()
	node.setup(q)
	node.open_resource_requested.connect(_on_open_resource)
	node.open_action_graph_requested.connect(_on_open_action_graph)
	node.quest_modified.connect(_on_quest_modified)
	graph.add_child(node)
	quest_nodes[q.id] = node
	quests_by_id[q.id] = q
	print("[QuestGraph] added node id=", q.id, " name=", node.name, " pos=", node.position_offset, " size=", node.size, " visible=", node.visible)


func _on_open_resource(res: Resource) -> void:
	# Opens ConditionSet in the standard Godot inspector on the right —
	# dynamic enum fields from SmartResource will also work there.
	plugin.get_editor_interface().edit_resource(res)


func _on_open_action_graph(action_set: ActionSet) -> void:
	if action_graph_editor:
		action_graph_editor.open(action_set)


func _on_quest_modified(_q: Quest) -> void:
	status_label.text = "Unsaved changes exist — click 'Save All'"


func _on_new_quest() -> void:
	var q := Quest.new()
	var new_id := "new_quest_%d" % quest_nodes.size()
	q.id = new_id
	q.title = "New Quest"

	var path := QUEST_DIR + new_id + ".tres"
	var err := ResourceSaver.save(q, path)
	if err != OK:
		status_label.text = "Error saving new quest: %s" % err
		return

	q = load(path) # reload so the resource has a correct resource_path
	_add_quest_node(q)
	status_label.text = "Created quest: " + new_id


func _on_save_all() -> void:
	if action_graph_editor:
		action_graph_editor.sync_positions_to_resource()

	var count := 0
	for id in quest_nodes:
		var node: QuestGraphNode = quest_nodes[id]
		node.sync_position_to_resource()
		if node.quest.resource_path == "":
			node.quest.resource_path = QUEST_DIR + node.quest.id + ".tres"
		var err := ResourceSaver.save(node.quest, node.quest.resource_path)
		if err == OK:
			count += 1
	status_label.text = "Saved quests: %d" % count


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_quest: Quest = quest_nodes[from_node].quest
	var to_quest: Quest = quest_nodes[to_node].quest

	if from_quest == to_quest or to_quest in from_quest.sub_quests:
		return

	from_quest.sub_quests.append(to_quest)
	graph.connect_node(from_node, from_port, to_node, to_port)
	_on_quest_modified(from_quest)


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_quest: Quest = quest_nodes[from_node].quest
	var to_quest: Quest = quest_nodes[to_node].quest

	from_quest.sub_quests.erase(to_quest)
	graph.disconnect_node(from_node, from_port, to_node, to_port)
	_on_quest_modified(from_quest)


func _on_delete_request(nodes: Array[StringName]) -> void:
	for node_name in nodes:
		var node: QuestGraphNode = graph.get_node_or_null(NodePath(node_name))
		if not node:
			continue
			
		var q: Quest = node.quest
		
		# 1. Remove connections from other quests (if they referenced this quest as a sub_quest)
		for other_id in quest_nodes:
			var other_node: QuestGraphNode = quest_nodes[other_id]
			if other_node.quest and q in other_node.quest.sub_quests:
				other_node.quest.sub_quests.erase(q)
				graph.disconnect_node(other_node.name, 0, node.name, 0)
		
		# 2. Remove file from disk if it exists
		if q.resource_path != "" and FileAccess.file_exists(q.resource_path):
			var err := DirAccess.remove_absolute(q.resource_path)
			if err != OK:
				push_warning("QuestGraph: failed to delete quest file '%s', error: %s" % [q.resource_path, err])
		
		# 3. Remove from dictionaries and clean up node memory
		quest_nodes.erase(q.id)
		quests_by_id.erase(q.id)
		graph.remove_child(node)
		node.free()
		
		_on_quest_modified(q)
		
	status_label.text = "Selected quests deleted"
