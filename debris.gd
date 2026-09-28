extends Node2D

var local_shape_owner
var local_shape_node


func _ready() -> void:
	$Label.hide()


func _on_area_shape_entered(
	_area_rid: RID,
	_area: Area2D,
	_area_shape_index: int,
	local_shape_index: int,
) -> void:
	local_shape_owner = $Interaction.shape_find_owner(local_shape_index)
	local_shape_node = $Interaction.shape_owner_get_owner(local_shape_owner)
	if local_shape_node.name == "Debris Interaction":
		$Label.show()


func _on_area_shape_exited(
	_area_rid: RID,
	_area: Area2D,
	_area_shape_index: int,
	_local_shape_index: int,
) -> void:
	$Label.hide()
