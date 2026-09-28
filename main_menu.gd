extends Node2D

var dialogue = load("res://Dialogue/dev_1_welcome.dialogue")
var dialogue_line = await dialogue.get_next_dialogue_line("start")


func _ready() -> void:
	AchievementManager.unlock_achievement("playtester_achievement")


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://indieflower_garden.tscn")
