extends StaticBody2D

static var input_handled_this_frame: bool = false

var can_interact: bool = false


func _ready() -> void:
	$"Interaction Notice".hide()
	$Time.hide()


func _process(_delta: float) -> void:
	$Time.text = str(int($"Removal Time".time_left)) + " seconds"
	input_handled_this_frame = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if can_interact and not input_handled_this_frame:
			input_handled_this_frame = true
			Log.pr("You can get stone stabs,stone,broken slabs,mossy slabs,mossy slabs")
			$"Removal Time".start()
			$Time.show()


func _on_interaction_body_entered(_body: Node2D) -> void:
	$"Interaction Notice".show()
	can_interact = true


func _on_interaction_body_exited(_body: Node2D) -> void:
	$"Interaction Notice".hide()
	$Time.hide()
	$"Removal Time".stop()
	can_interact = false


func _on_interact_timer_timeout() -> void:
	set_process(false)


func _on_removal_time_timeout() -> void:
	queue_free()
