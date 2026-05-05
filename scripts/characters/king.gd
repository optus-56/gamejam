extends CharacterBody2D

const SPEED := 100
const DAMAGE := 1
const ATTACK_COOLDOWN := 0.4
const JUMP_FORCE := -400.0  # Negative because up is negative Y
const GRAVITY := 800.0

# Damage will happen when the "attack" animation reaches this frame (0-based)
const HIT_FRAME: int = 2

# Health bar
const HEALTH_BAR_WIDTH := 40
const HEALTH_BAR_HEIGHT := 4
const HEALTH_BAR_OFFSET_Y := -62  # Offset above the mob

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
var player_in_hitbox: bool = false
var hitbox_target: Node = null
var player_is_attacking: bool = false

var current_attack: int = 1  # Track which attack (1, 2, or 3)
var is_jumping: bool = false
var is_falling: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_1_hitbox: Area2D = $Attack1Hitbox
@onready var attack_2_hitbox: Area2D = $Attack2Hitbox
@onready var attack_3_hitbox: Area2D = $Attack3Hitbox
@onready var detect: Area2D = $Detect
@onready var sfx: AudioStreamPlayer2D = $SFX

func _ready() -> void:
	add_to_group("enemy")
	
	# Set up all attack hitboxes
	for hitbox in [attack_1_hitbox, attack_2_hitbox, attack_3_hitbox]:
		hitbox.monitoring = true
		hitbox.monitorable = false
		hitbox.set_collision_layer_value(1, false)
		hitbox.set_collision_layer_value(2, false)
		hitbox.set_collision_mask_value(1, true)   # Detect player on layer 1
		hitbox.set_collision_mask_value(2, false)
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.body_exited.connect(_on_hitbox_body_exited)
	
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
	
	animated_sprite.flip_h = true

func _physics_process(_delta: float) -> void:
	if dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * _delta
		is_falling = true
		if not is_jumping and not is_attacking:
			animated_sprite.play("fall")
	else:
		is_falling = false
		is_jumping = false

	# While hurt: stop and don't attack/chase
	if is_hurt:
		velocity.x = 0.0
		move_and_slide()
		return

	if is_attacking:
		velocity.x = 0.0
		move_and_slide()
		return

	# If player is attacking, on floor, facing us, and we're on ground, jump to dodge
	if player_is_attacking and player != null and player.is_on_floor() and not is_attacking and not is_jumping and is_on_floor():
		# Check if player is facing the King
		if _is_player_facing_king():
			_perform_jump()
			move_and_slide()
			return

	# If player is in hitbox and we're able to attack, begin attack immediately (even while jumping)
	if player_in_hitbox and can_attack and not is_attacking:
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

		# Facing rule (sprite default faces LEFT; if yours differs, invert this)
		if dir != 0.0:
			animated_sprite.flip_h = player.global_position.x < global_position.x
			_update_hitbox_position()

		if not is_jumping:  # Don't change animation while jumping
			animated_sprite.play("run" if dir != 0.0 else "idle")
	else:
		velocity.x = 0.0
		if not is_jumping and not is_attacking:  # Don't change animation while jumping/attacking
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

func _is_player_facing_king() -> bool:
	if player == null:
		return false
	
	# Get the direction from player to King
	var dir_to_king: float = global_position.x - player.global_position.x
	
	# Check player's flip_h to determine facing direction
	# If flip_h is false, player faces right; if true, player faces left
	var player_facing_right: bool = not player.animated_sprite.flip_h
	
	# If player faces right and King is to the right, they're facing each other
	if player_facing_right and dir_to_king > 0:
		return true
	
	# If player faces left and King is to the left, they're facing each other
	if not player_facing_right and dir_to_king < 0:
		return true
	
	return false

func _perform_jump() -> void:
	is_jumping = true
	velocity.y = JUMP_FORCE
	animated_sprite.play("jump")

func _start_attack() -> void:
	if is_attacking or not can_attack or dead or is_hurt:
		return

	is_attacking = true
	can_attack = false
	did_hit_this_attack = false
	# Don't stop velocity.x if jumping - let it maintain momentum
	if is_on_floor():
		velocity.x = 0.0

	# Face player
	if player != null:
		animated_sprite.flip_h = player.global_position.x < global_position.x
		_update_hitbox_position()

	# Play current attack animation
	var attack_name = "attack" + str(current_attack)
	animated_sprite.play(attack_name)
	sfx.play()
	
	# Cycle to next attack (1 -> 2 -> 3 -> 1)
	current_attack += 1
	if current_attack > 3:
		current_attack = 1

func _update_hitbox_position() -> void:
	# Flip all hitbox scales to match sprite direction
	var scale_value = -1.0 if animated_sprite.flip_h else 1.0
	
	attack_1_hitbox.scale.x = scale_value
	attack_2_hitbox.scale.x = scale_value
	attack_3_hitbox.scale.x = scale_value

func _get_current_hitbox() -> Area2D:
	# Return the hitbox for the current animation
	var current_animation = animated_sprite.animation
	if current_animation == "attack1":
		return attack_1_hitbox
	elif current_animation == "attack2":
		return attack_2_hitbox
	elif current_animation == "attack3":
		return attack_3_hitbox
	return attack_1_hitbox

func _on_detect_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body as Node2D

func _on_detect_body_exited(body: Node) -> void:
	if body == player:
		player = null
		player_is_attacking = false

func _on_hitbox_body_entered(body: Node) -> void:
	if not (body.is_in_group("player") and body.has_method("take_damage")):
		return
	player_in_hitbox = true
	hitbox_target = body

func _on_hitbox_body_exited(body: Node) -> void:
	if body == hitbox_target:
		player_in_hitbox = false
		hitbox_target = null

func _on_frame_changed() -> void:
	# Only apply damage during attack animations
	var current_animation = animated_sprite.animation
	if not current_animation in ["attack1", "attack2", "attack3"]:
		return
	if not is_attacking or did_hit_this_attack:
		return
	if dead or is_hurt:
		return

	if animated_sprite.frame == HIT_FRAME:
		did_hit_this_attack = true

		# Deal damage only if still in range *at the hit frame*
		if player_in_hitbox and hitbox_target != null and is_instance_valid(hitbox_target):
			hitbox_target.take_damage(DAMAGE)

func _on_animation_finished() -> void:
	# Only react to the end of attack animations
	var current_animation = animated_sprite.animation
	if not current_animation in ["attack1", "attack2", "attack3"]:
		return

	# End attack state and start cooldown
	is_attacking = false

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
	print("King HP:", hp, "/", max_hp)
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

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("hit"):
		animated_sprite.play("hit")

	await get_tree().create_timer(HURT_LOCK_TIME).timeout
	is_hurt = false
	if not dead:
		can_attack = true

func set_player_attacking(attacking: bool) -> void:
	player_is_attacking = attacking

func die() -> void:
	dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)

	for hitbox in [attack_1_hitbox, attack_2_hitbox, attack_3_hitbox]:
		hitbox.monitoring = false
		hitbox.monitorable = false
	detect.monitoring = false
	detect.monitorable = false

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished
	
	get_tree().current_scene.mob_died()
	
	queue_free()
