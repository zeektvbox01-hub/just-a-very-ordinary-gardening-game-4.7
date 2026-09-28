@tool
class_name Quest
extends Resource

# See comment in quest_stage.gd: use preload instead of global
# class_name so that .new() doesn't race with the editor's
# asynchronous re-registration of global classes.
const ConditionSet = preload("res://addons/quest_graph_editor/scripts/condition_set.gd")

enum Status { LOCKED, AVAILABLE, ACTIVE, COMPLETED, FAILED }

signal quest_status_changed(quest: Quest, status: Status)
signal stage_status_changed(quest: Quest, stage: QuestStage, status: QuestStage.Status)

@export var id: String = ""
@export var title: String = ""

## Prerequisites — conditions under which the quest becomes available.
@export var prerequisites: ConditionSet

## Completion condition — conditions under which the quest is considered completed.
@export var completion_condition: ConditionSet

## If enabled, the quest automatically transitions from AVAILABLE -> ACTIVE as soon
## as prerequisites are met, without requiring an explicit call to QuestManager.start_quest().
## If disabled, the quest waits for a manual start (dialogue/trigger/player UI).
@export var auto_start: bool = false

## Events inside the quest (started/active/completed), each with its own conditions.
@export var stages: Array[QuestStage] = []

## Sub-quests — rendered in the graph as connections from this node.
@export var sub_quests: Array[Quest] = []

## Editor only: node position in GraphEdit, to prevent the graph from "jumping" between sessions.
@export var editor_graph_position: Vector2 = Vector2.ZERO

var status: Status = Status.LOCKED


func _init() -> void:
	if prerequisites == null:
		prerequisites = ConditionSet.new()
	if completion_condition == null:
		completion_condition = ConditionSet.new()


func set_status(new_status: Status) -> void:
	if status == new_status:
		return
	status = new_status
	quest_status_changed.emit(self, status)
