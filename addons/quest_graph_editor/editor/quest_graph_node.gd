@tool
class_name QuestGraphNode
extends GraphNode

const FoldableSection = preload("res://addons/quest_graph_editor/editor/foldable_section.gd")
const QuestStage = preload("res://addons/quest_graph_editor/scripts/quest_stage.gd")

## Emitted when the user wants to open a sub-resource (ConditionSet)
## in the standard Godot inspector for detailed editing.
signal open_resource_requested(resource: Resource)

## Emitted when the user wants to open the stage action graph
## (ActionSet) in a separate GraphEdit editor — not in the standard inspector.
signal open_action_graph_requested(action_set: ActionSet)

## Emitted upon any modification of quest fields (to flag "needs saving").
signal quest_modified(quest: Quest)

var quest: Quest


func setup(p_quest: Quest) -> void:
	quest = p_quest
	name = _safe_node_name(quest.id)
	title = quest.title if quest.title != "" else quest.id
	position_offset = quest.editor_graph_position

	# One input (I am someone's sub-quest) and one output (I have sub-quests).
	# Both are on slot 0 — the specific stage/section the connection belongs to
	# cannot be marked in GraphEdit, so the connection is treated at the whole-quest level.
	set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)

	resizable = true
	custom_minimum_size = Vector2(260, 0)

	_build_ui()


func _safe_node_name(id: String) -> String:
	return id if id != "" else "quest_%d" % get_instance_id()


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var id_edit := LineEdit.new()
	id_edit.text = quest.id
	id_edit.placeholder_text = "quest_id"
	id_edit.tooltip_text = "Unique quest ID"
	id_edit.text_changed.connect(_on_id_changed)
	add_child(id_edit)

	var title_edit := LineEdit.new()
	title_edit.text = quest.title
	title_edit.placeholder_text = "Title"
	title_edit.text_changed.connect(_on_title_changed)
	add_child(title_edit)

	var auto_start_check := CheckBox.new()
	auto_start_check.text = "Auto-start (immediate AVAILABLE -> ACTIVE)"
	auto_start_check.button_pressed = quest.auto_start
	auto_start_check.toggled.connect(func(pressed: bool):
		quest.auto_start = pressed
		quest_modified.emit(quest)
	)
	add_child(auto_start_check)

	add_child(HSeparator.new())

	add_child(_make_condition_row("Preq", quest.prerequisites))
	add_child(_make_condition_row("Req", quest.completion_condition))

	add_child(HSeparator.new())

	var stages_label := Label.new()
	stages_label.text = "Stages (%d)" % quest.stages.size()
	add_child(stages_label)

	for stage in quest.stages:
		add_child(_make_stage_card(stage))

	var add_stage_btn := Button.new()
	add_stage_btn.text = "+ Add Stage"
	add_stage_btn.pressed.connect(_on_add_stage)
	add_child(add_stage_btn)

	add_child(HSeparator.new())

	var sub_label := Label.new()
	sub_label.text = "Sub-quests: %d (drag connection from right port)" % quest.sub_quests.size()
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(sub_label)


func _make_condition_row(label_text: String, cs: ConditionSet) -> Control:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 40
	row.add_child(label)

	var summary_btn := Button.new()
	summary_btn.text = cs.get_summary()
	summary_btn.tooltip_text = "Open in inspector to edit conditions"
	summary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_btn.pressed.connect(func(): open_resource_requested.emit(cs))
	row.add_child(summary_btn)

	return row


func _make_stage_card(stage: QuestStage) -> Control:
	var section := FoldableSection.new(stage.title if stage.title != "" else (stage.id if stage.id != "" else "Stage"))

	var id_edit := LineEdit.new()
	id_edit.text = stage.id
	id_edit.placeholder_text = "stage_id"
	id_edit.text_changed.connect(func(t: String):
		stage.id = t
		section.set_title(stage.title if stage.title != "" else t)
		quest_modified.emit(quest)
	)
	section.add_content(id_edit)

	var title_edit := LineEdit.new()
	title_edit.text = stage.title
	title_edit.placeholder_text = "Stage title"
	title_edit.text_changed.connect(func(t: String):
		stage.title = t
		section.set_title(t if t != "" else stage.id)
		quest_modified.emit(quest)
	)
	section.add_content(title_edit)

	var status_label := Label.new()
	status_label.text = "Runtime status: %s" % QuestStage.Status.keys()[stage.status]
	section.add_content(status_label)

	section.add_content(_make_condition_row("Trigger", stage.trigger_condition))
	section.add_content(_make_condition_row("Complete", stage.complete_condition))

	var actions_btn := Button.new()
	actions_btn.text = "Actions: " + stage.actions.get_summary()
	actions_btn.tooltip_text = "Open action graph (parallel/sequence/delay)"
	actions_btn.pressed.connect(func(): open_action_graph_requested.emit(stage.actions))
	section.add_content(actions_btn)

	var remove_btn := Button.new()
	remove_btn.text = "✕ Remove Stage"
	remove_btn.pressed.connect(func():
		quest.stages.erase(stage)
		quest_modified.emit(quest)
		_build_ui()
	)
	section.add_content(remove_btn)

	return section


func _on_id_changed(t: String) -> void:
	quest.id = t
	name = _safe_node_name(t)
	if quest.title == "":
		title = t
	quest_modified.emit(quest)


func _on_title_changed(t: String) -> void:
	quest.title = t
	title = t if t != "" else quest.id
	quest_modified.emit(quest)


func _on_add_stage() -> void:
	var stage := QuestStage.new()
	stage.id = "stage_%d" % quest.stages.size()
	quest.stages.append(stage)
	quest_modified.emit(quest)
	_build_ui()


func sync_position_to_resource() -> void:
	quest.editor_graph_position = position_offset
