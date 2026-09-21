extends CharacterBody2D

@export var speed: float = 300

func _physics_process(delta:float):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
