extends CharacterBody2D

@export var speed: float = 300

var idle: bool = false


func _physics_process(_delta: float):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		idle = false
		velocity = direction * speed
		if Input.is_action_pressed("ui_right"):
			$AnimatedSprite2D.animation = "front" # Working on new animation
		elif Input.is_action_pressed("ui_left"):
			$AnimatedSprite2D.animation = "front" # Working on new animation
		elif Input.is_action_pressed("ui_down"):
			$AnimatedSprite2D.animation = "front"
		elif Input.is_action_pressed("ui_up"):
			$AnimatedSprite2D.animation = "back"
	else:
		$AnimatedSprite2D.animation = "idle"
		velocity = Vector2.ZERO
	$AnimatedSprite2D.play()
	move_and_slide()


func to_pretty():
	return { val = 12 }
