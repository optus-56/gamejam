extends CharacterBody2D

const SPEED = 140.0
const JUMP_VELOCITY = -400.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_attacking := false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	var direction := Input.get_axis("move_left", "move_right")
	
	# start attack once
	if Input.is_action_just_pressed("attack1") and is_on_floor() and not is_attacking:
		is_attacking = true
		animated_sprite.play("attack1")
	elif Input.is_action_just_pressed("attack2") and is_on_floor() and not is_attacking:
		is_attacking = true
		animated_sprite.play("attack2")

	# while attacking, don't restart other animations
	if is_attacking:
		velocity.x = 0 # optional
		move_and_slide()
		return

	# jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	if not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("jump")
		else:
			animated_sprite.play("fall")
	else:
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "attack1" or "attack2":
		is_attacking = false
