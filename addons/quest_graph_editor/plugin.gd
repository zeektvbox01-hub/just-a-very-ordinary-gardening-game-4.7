@tool
extends EditorPlugin

const QuestGraphDock = preload("res://addons/quest_graph_editor/editor/quest_graph_dock.gd")
const ActionGraphEditor = preload("res://addons/quest_graph_editor/editor/action_graph_editor.gd")

var dock: Control
var action_graph_editor: Window


func _enter_tree() -> void:
	dock = QuestGraphDock.new()
	dock.name = "Quest Graph"
	dock.plugin = self
	get_editor_interface().get_editor_main_screen().add_child(dock)
	_make_visible(false)

	action_graph_editor = ActionGraphEditor.new()
	get_editor_interface().get_base_control().add_child(action_graph_editor)
	action_graph_editor.graph_modified.connect(func():
		dock.status_label.text = "Граф действий изменён — нажми «Сохранить всё»"
	)
	dock.action_graph_editor = action_graph_editor


func _exit_tree() -> void:
	if dock:
		dock.queue_free()
	if action_graph_editor:
		action_graph_editor.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(next_visible: bool) -> void:
	if dock:
		dock.visible = next_visible


func _get_plugin_name() -> String:
	return "Quest Graph"


func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("GraphEdit", "EditorIcons")
