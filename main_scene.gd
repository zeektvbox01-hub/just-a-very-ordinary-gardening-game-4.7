extends Node2D


func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred("res://main_menu.tscn")
