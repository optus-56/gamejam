extends CharacterBody2D

const SPEED := 100
const DAMAGE := 3
const ATTACK_COOLDOWN := 0.4
const GRAVITY := 800.0
const ATTACK_RANGE := 80.0  # Distance to trigger attack

# Damage will happen when the "attack" animation reaches this frame (0-based)
const HIT_FRAME: Array[int] = [9,10,11,12,13]

# Health bar
const HEALTH_BAR_WIDTH := 40
const HEALTH_BAR_HEIGHT := 4
const HEALTH_BAR_OFFSET_Y := -130  # Offset above the mob

# HP + reactions
var max_hp: int = 10
var hp: int = 10
var dead: bool = false

const HURT_LOCK_TIME: float = 0.1
var is_hurt: bool = false

var can_attack: bool = true
var is_attacking: bool = false
var did_hit_this_attack: bool = false

var player: Node2D = null
var is_falling: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var detect: Area2D = $Detect
@onready var sfx: AudioStreamPlayer2D = $SFX

func _ready() -> void:
	add_to_group("enemy")
	
	# Set up attack hitbox
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false
	attack_hitbox.set_collision_layer_value(1, false)
	attack_hitbox.set_collision_layer_value(2, false)
	attack_hitbox.set_collision_mask_value(1, true)   # Detect player on layer 1
	attack_hitbox.set_collision_mask_value(2, false)
	
	detect.monitoring = true
	detect.monitorable = false
	
	set_collision_layer_value(2, true)
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, true)  # Can collide with level/walls on layer 2
	set_collision_mask_value(1, false)
	
	# Set up detect area to detect player on layer 1
	detect.set_collision_layer_value(1, false)
	detect.set_collision_layer_value(2, false)
	detect.set_collision_mask_value(1, true)   # Detect player on layer 1
	detect.set_collision_mask_value(2, false)
	
	detect.body_entered.connect(_on_detect_body_entered)
	detect.body_exited.connect(_on_detect_body_exited)

	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	animated_sprite.flip_h = false

func _physics_process(_delta: float) -> void:
	if dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * _delta
		is_falling = true
		if not is_attacking:
			animated_sprite.play("fall")
	else:
		is_falling = false

	# While hurt: stop and don't attack/chase
	if is_hurt:
		velocity.x = 0.0
		move_and_slide()
		return

	if is_attacking:
		velocity.x = 0.0
		move_and_slide()
		return

	# Attack if player is detected AND close enough
	if player != null and can_attack and not is_attacking:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		if distance_to_player < ATTACK_RANGE:
			_start_attack()
			move_and_slide()
			return

	# Otherwise chase player if detected
	if player != null:
		var dx: float = player.global_position.x - global_position.x
		var dir: float = 0.0
		if dx > 0.0:
			dir = 1.0
		elif dx < 0.0:
			dir = -1.0

		velocity.x = dir * SPEED

		# Face player
		if dir != 0.0:
			animated_sprite.flip_h = player.global_position.x > global_position.x
			_update_hitbox_position()

		animated_sprite.play("run" if dir != 0.0 else "idle")
	else:
		velocity.x = 0.0
		if not is_attacking:  # Don't change animation while attacking
			animated_sprite.play("idle")

	move_and_slide()

func _draw() -> void:
	# Draw health bar above the mob
	var bar_position = Vector2(-HEALTH_BAR_WIDTH / 2, HEALTH_BAR_OFFSET_Y)
	
	# Draw background (dark red)
	draw_rect(Rect2(bar_position, Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)), Color.DARK_RED)
	
	# Draw health (green)
	var health_percentage = float(hp) / float(max_hp)
	var health_width = HEALTH_BAR_WIDTH * health_percentage
	draw_rect(Rect2(bar_position, Vector2(health_width, HEALTH_BAR_HEIGHT)), Color.GREEN)
	
	# Draw border (white)
	draw_rect(Rect2(bar_position, Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)), Color.WHITE, false, 1.0)

func _start_attack() -> void:
	if is_attacking or not can_attack or dead or is_hurt:
		return

	is_attacking = true
	can_attack = false
	did_hit_this_attack = false
	velocity.x = 0.0

	# Face player
	if player != null:
		animated_sprite.flip_h = player.global_position.x > global_position.x
		_update_hitbox_position()

	# Enable attack hitbox
	attack_hitbox.monitoring = true
	attack_hitbox.monitorable = true

	# Play attack animation
	animated_sprite.play("attack")

func _update_hitbox_position() -> void:
	# Flip hitbox scale to match sprite direction
	var scale_value = -1.0 if animated_sprite.flip_h else 1.0
	attack_hitbox.scale.x = scale_value

func _on_detect_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body as Node2D

func _on_detect_body_exited(body: Node) -> void:
	if body == player:
		player = null

func _on_frame_changed() -> void:
	# Only apply damage during attack animation
	var current_animation = animated_sprite.animation
	if current_animation != "attack":
		return
	if not is_attacking or did_hit_this_attack:
		return
	if dead or is_hurt:
		return

	if animated_sprite.frame in HIT_FRAME:
		did_hit_this_attack = true

		# Check for overlapping bodies at the hit frame
		for body in attack_hitbox.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(DAMAGE)
				print("Knight dealt ", DAMAGE, " damage!")
				break

func _on_animation_finished() -> void:
	# Only react to the end of attack animation
	var current_animation = animated_sprite.animation
	if current_animation != "attack":
		return

	# End attack state and start cooldown
	is_attacking = false
	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false

	get_tree().create_timer(ATTACK_COOLDOWN).timeout.connect(func ():
		# Don't re-enable attacks if dead/hurt
		if dead:
			return
		can_attack = true
	)

func take_damage(amount: int) -> void:
	if dead:
		return

	hp = max(hp - amount, 0)
	print("Knight HP:", hp, "/", max_hp)
	queue_redraw()

	if hp <= 0:
		die()
		return

	# Hurt reaction (play "hit", briefly lock movement/attacks)
	is_hurt = true
	is_attacking = false
	can_attack = false
	did_hit_this_attack = true
	velocity.x = 0.0

	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("hit"):
		animated_sprite.play("hit")

	await get_tree().create_timer(HURT_LOCK_TIME).timeout
	is_hurt = false
	if not dead:
		can_attack = true

func die() -> void:
	dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)

	attack_hitbox.monitoring = false
	attack_hitbox.monitorable = false
	detect.monitoring = false
	detect.monitorable = false

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished

	get_tree().current_scene.mob_died()

	queue_free()
