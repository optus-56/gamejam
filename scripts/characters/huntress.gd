extends CharacterBody2D

const SPEED := 100
const DAMAGE := 1
const ATTACK_COOLDOWN := 0.4
const GRAVITY := 800.0

# Damage will happen when the "attack" animation reaches this frame (0-based)
const HIT_FRAME: int = 2
const SPEAR_THROW_FRAME: int = 4  # Frame when spear should be thrown

# Range settings
const MELEE_RANGE := 150.0  # Distance for melee attacks
const LONG_RANGE := 250.0   # Distance for spear throws (must be > MELEE_RANGE)

# Spear settings
const SPEAR_DAMAGE := 2
const SPEAR_SPEED := 400.0
const SPEAR_SCENE := preload("res://scenes/spear.tscn")

# Health bar
const HEALTH_BAR_WIDTH := 40
const HEALTH_BAR_HEIGHT := 4
const HEALTH_BAR_OFFSET_Y := -62

# HP + reactions
var max_hp: int = 6
var hp: int = 6
var dead: bool = false

const HURT_LOCK_TIME: float = 0.1
var is_hurt: bool = false

var can_attack: bool = true
var is_attacking: bool = false
var did_hit_this_attack: bool = false
var spear_thrown: bool = false

var player: Node2D = null
var player_in_hitbox: bool = false
var hitbox_target: Node = null
var player_is_attacking: bool = false

var current_attack: int = 1
var is_falling: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_1_hitbox: Area2D = $Attack1Hitbox
@onready var attack_2_hitbox: Area2D = $Attack2Hitbox
@onready var attack_3_hitbox: Area2D = $Attack3Hitbox
@onready var detect: Area2D = $Detect
@onready var attack_1sfx: AudioStreamPlayer2D = $SFX/Attack1SFX
@onready var attack_2sfx: AudioStreamPlayer2D = $SFX/Attack2SFX

func _ready() -> void:
	add_to_group("enemy")
	
	# Set up all attack hitboxes
	for hitbox in [attack_1_hitbox, attack_2_hitbox, attack_3_hitbox]:
		hitbox.monitoring = true
		hitbox.monitorable = false
		hitbox.set_collision_layer_value(1, false)
		hitbox.set_collision_layer_value(2, false)
		hitbox.set_collision_mask_value(1, true)
		hitbox.set_collision_mask_value(2, false)
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.body_exited.connect(_on_hitbox_body_exited)
	
	detect.monitoring = true
	detect.monitorable = false
	
	set_collision_layer_value(2, true)
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, true)
	set_collision_mask_value(1, false)
	
	detect.set_collision_layer_value(1, false)
	detect.set_collision_layer_value(2, false)
	detect.set_collision_mask_value(1, true)
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

	# If player is attacking, on floor, facing us, and we're on ground, jump to dodge
	if player_is_attacking and player != null and player.is_on_floor() and not is_attacking and is_on_floor():
		if _is_player_facing_huntress():
			# Don't jump, just stay still or move back
			velocity.x = 0.0
			move_and_slide()
			return

	# Check if we should attack based on distance and can_attack
	if player != null and can_attack and not is_attacking and is_on_floor():
		var distance = _get_distance_to_player()
		
		# Long range: attack from far away
		if distance > LONG_RANGE:
			_start_attack_spear()
			move_and_slide()
			return
		# Melee range: attack when close
		elif distance <= MELEE_RANGE and player_in_hitbox:
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

		if dir != 0.0:
			animated_sprite.flip_h = player.global_position.x < global_position.x
			_update_hitbox_position()

		if not is_attacking:
			animated_sprite.play("run" if dir != 0.0 else "idle")
	else:
		velocity.x = 0.0
		if not is_attacking:
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

func _get_distance_to_player() -> float:
	if player == null:
		return 0.0
	return abs(player.global_position.x - global_position.x)

func _is_long_range() -> bool:
	return _get_distance_to_player() > LONG_RANGE

func _is_player_facing_huntress() -> bool:
	if player == null:
		return false
	
	var dir_to_huntress: float = global_position.x - player.global_position.x
	var player_facing_right: bool = not player.animated_sprite.flip_h
	
	if player_facing_right and dir_to_huntress > 0:
		return true
	
	if not player_facing_right and dir_to_huntress < 0:
		return true
	
	return false

func _start_attack_spear() -> void:
	"""Start spear attack at long range"""
	if is_attacking or not can_attack or dead or is_hurt:
		return

	is_attacking = true
	can_attack = false
	did_hit_this_attack = false
	spear_thrown = false
	
	if is_on_floor():
		velocity.x = 0.0

	if player != null:
		animated_sprite.flip_h = player.global_position.x < global_position.x
		_update_hitbox_position()

	print("Huntress throwing spear! Distance: ", _get_distance_to_player())
	animated_sprite.play("attack3")

func _start_attack() -> void:
	"""Start melee attack at close range"""
	if is_attacking or not can_attack or dead or is_hurt:
		return

	is_attacking = true
	can_attack = false
	did_hit_this_attack = false
	spear_thrown = false
	
	if is_on_floor():
		velocity.x = 0.0

	if player != null:
		animated_sprite.flip_h = player.global_position.x < global_position.x
		_update_hitbox_position()

	# Cycle between attack1 and attack2 for melee
	var attack_name = "attack" + str(current_attack)
	current_attack += 1
	if current_attack > 2:
		current_attack = 1
	
	print("Huntress melee attack: ", attack_name, " Distance: ", _get_distance_to_player())
	animated_sprite.play(attack_name)
	attack_1sfx.play()

func _update_hitbox_position() -> void:
	var scale_value = -1.0 if animated_sprite.flip_h else 1.0
	
	attack_1_hitbox.scale.x = scale_value
	attack_2_hitbox.scale.x = scale_value
	attack_3_hitbox.scale.x = scale_value

func _throw_spear() -> void:
	if not SPEAR_SCENE or player == null:
		return
	
	var spear = SPEAR_SCENE.instantiate()
	get_parent().add_child(spear)
	spear.global_position = global_position
	
	var direction_to_player = (player.global_position - global_position).x
	spear.spear_direction = 1 if direction_to_player > 0 else -1
	spear.spear_damage = SPEAR_DAMAGE
	print("Spear thrown!")

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
	# Throw spear during attack3 animation
	if animated_sprite.animation == "attack3" and animated_sprite.frame == SPEAR_THROW_FRAME and not spear_thrown:
		spear_thrown = true
		_throw_spear()
	
	var current_animation = animated_sprite.animation
	if not current_animation in ["attack1", "attack2", "attack3"]:
		return
	if not is_attacking or did_hit_this_attack:
		return
	if dead or is_hurt:
		return

	if animated_sprite.frame == HIT_FRAME:
		did_hit_this_attack = true

		if player_in_hitbox and hitbox_target != null and is_instance_valid(hitbox_target):
			hitbox_target.take_damage(DAMAGE)

func _on_animation_finished() -> void:
	var current_animation = animated_sprite.animation
	if not current_animation in ["attack1", "attack2", "attack3"]:
		return

	is_attacking = false

	get_tree().create_timer(ATTACK_COOLDOWN).timeout.connect(func ():
		if dead:
			return
		can_attack = true
	)

func take_damage(amount: int) -> void:
	if dead:
		return

	hp = max(hp - amount, 0)
	print("Huntress HP:", hp, "/", max_hp)
	queue_redraw()

	if hp <= 0:
		die()
		return

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

	# Throw spear before dying (only if long range)
	if player != null and _is_long_range():
		_throw_spear()

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished
		
	get_tree().current_scene.mob_died()

	queue_free()
