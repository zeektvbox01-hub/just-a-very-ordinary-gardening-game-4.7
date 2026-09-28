@tool
class_name QuestStage
extends Resource

# preload вместо обращения по глобальному class_name: во время
# редактирования (после любого сохранения скрипта) Godot асинхронно
# перерегистрирует глобальные классы ("Registering global classes...").
# Если .new() вызвать по глобальному имени в этот момент, падает
# "Invalid call. Nonexistent function 'new' in base 'GDScript'".
# preload грузит нужный скрипт синхронно и не зависит от этой гонки.
const ConditionSet = preload("res://addons/quest_graph_editor/scripts/condition_set.gd")
const ActionSet = preload("res://addons/quest_graph_editor/scripts/action_set.gd")

enum Status { PENDING, ACTIVE, COMPLETED }

signal stage_status_changed(stage: QuestStage, status: Status)

@export var id: String = ""
@export var title: String = ""

## Условия, при которых стадия становится активной (started).
@export var trigger_condition: ConditionSet

## Условия, при которых стадия считается выполненной (completed).
@export var complete_condition: ConditionSet

## Что происходит в мире, когда стадия завершается.
@export var actions: ActionSet

var status: Status = Status.PENDING


func _init() -> void:
	if trigger_condition == null:
		trigger_condition = ConditionSet.new()
	if complete_condition == null:
		complete_condition = ConditionSet.new()
	if actions == null:
		actions = ActionSet.new()


func set_status(new_status: Status) -> void:
	if status == new_status:
		return
	status = new_status
	
	# Если стадия завершилась, триггерим завершение всех действий набора
	if status == Status.COMPLETED and actions != null:
		actions.stage_ended()
	stage_status_changed.emit(self, status)
	
