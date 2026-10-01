extends Node2D


func _ready() -> void:
	AchievementManager.unlock_achievement("playtester_achievement")


func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://indieflower_garden.tscn")
