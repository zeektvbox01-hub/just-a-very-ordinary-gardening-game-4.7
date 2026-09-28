extends Node
## Autoload: QuestManager

signal quest_status_changed(quest: Quest, status: Quest.Status)
signal stage_status_changed(quest: Quest, stage: QuestStage, status: QuestStage.Status)

var quests: Dictionary = {} # id -> Quest

var _evaluating: bool = false
var _dirty: bool = false


func _ready() -> void:
	for quest in IdRegistry.get_all_resource("quests") as Array[Quest]:
		register(quest)

func register(quest: Quest) -> void:
	quests[quest.id] = quest
	for sub in quest.sub_quests:
		register(sub)
	_evaluate(quest)


func notify_changes() -> void:
	print("notify_changes")
	print(GameState.data)
	if _evaluating:
		_dirty = true
		return

	_evaluating = true
	_dirty = true
	while _dirty:
		_dirty = false
		for q in quests.values():
			_evaluate(q)
	_evaluating = false


func _evaluate(q: Quest) -> void:
	if q.status == Quest.Status.LOCKED and q.prerequisites.is_met():
		_set_quest_status(q, Quest.Status.AVAILABLE)

	# auto_start: не ждём ручного start_quest() — сразу активируем,
	# как только квест стал доступен. Тот же вызов _evaluate() дальше
	# ниже сразу обработает и стадии, без ожидания следующего state_changed.
	if q.status == Quest.Status.AVAILABLE and q.auto_start:
		_set_quest_status(q, Quest.Status.ACTIVE)
	if q.status == Quest.Status.ACTIVE:
		for stage in q.stages:
			
			_evaluate_stage(q, stage)

		if q.completion_condition.is_met():
			_set_quest_status(q, Quest.Status.COMPLETED)
			for stage in q.stages:
				stage.actions.quest_ended()
				stage.actions.stage_ended()


func _evaluate_stage(q: Quest, stage: QuestStage) -> void:
	
	if stage.status == QuestStage.Status.PENDING and stage.trigger_condition.is_met():
		stage.set_status(QuestStage.Status.ACTIVE)
		stage_status_changed.emit(q, stage, stage.status)
		stage.actions.apply_all(self)
		
		
	elif stage.status == QuestStage.Status.ACTIVE and stage.complete_condition.is_met():
		stage.set_status(QuestStage.Status.COMPLETED)
		stage_status_changed.emit(q, stage, stage.status)


func _set_quest_status(q: Quest, new_status: Quest.Status) -> void:
	q.set_status(new_status)
	quest_status_changed.emit(q, new_status)


func start_quest(id: String) -> void:
	var q: Quest = quests.get(id)
	if q and q.status == Quest.Status.AVAILABLE:
		_set_quest_status(q, Quest.Status.ACTIVE)



func refresh_all() -> void:
	for q in quests.values():
		_evaluate(q)
