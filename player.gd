extends CharacterBody2D

@export var speed: float = 300
var idle: bool = false

func to_pretty():
	return {val=12}

func _physics_process(delta:float):
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
			Log.info("Idle")
		if idle == true and $AnimatedSprite2D.animation == "idle":
			$AnimatedSprite2D.stop()
		elif idle != true and $AnimatedSprite2D.animation == "idle":
			$AnimatedSprite2D.play()
			idle = true
		elif idle == true and $AnimatedSprite2D.animation != "idle":
			$AnimatedSprite2D.play()
			idle = false
		elif idle != true and $AnimatedSprite2D.animation != "idle":
			$AnimatedSprite2D.play()
		else:
			Log.err("Error 100000-Impossible Situation")
	else:
		velocity = Vector2.ZERO
	move_and_slide()
