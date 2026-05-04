extends CharacterBody2D

const SPEED := 140.0
const JUMP_VELOCITY := -375.0

const DASH_SPEED := 500.0
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.4

# Wall jump / slide tuning
const WALL_SLIDE_SPEED := 120.0
const WALL_JUMP_VELOCITY := -380.0
const WALL_JUMP_PUSH := 260.0

# Attack cooldown
const ATTACK1_COOLDOWN := 0.6
const ATTACK2_COOLDOWN := 0.7
const DASH_ATTACK_COOLDOWN := 1.0

# Health bar
const HEALTH_BAR_WIDTH := 40
const HEALTH_BAR_HEIGHT := 4
const HEALTH_BAR_OFFSET_Y := -50  # Offset above the player

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# NEW tree: AttackRoot contains both hitboxes
@onready var attack_root: Node2D = $AttackRoot
@onready var attack_1_hit_box: Area2D = $AttackRoot/Attack1HitBox
@onready var attack_2_hit_box: Area2D = $AttackRoot/Attack2HitBox
@onready var dash_attack_hit_box: Area2D = $AttackRoot/DashAttackHitBox
@onready var sword_slash_1: AudioStreamPlayer2D = $SFX/SwordSlash1
@onready var sword_slash_2: AudioStreamPlayer2D = $SFX/SwordSlash2
@onready var dash_attack: AudioStreamPlayer2D = $SFX/DashAttack
@onready var walk: AudioStreamPlayer2D = $SFX/walk

var is_attacking := false
var is_dashing := false
var can_dash := true
var can_attack := true
var attack1_ready := true
var attack2_ready := true
var dash_attack_ready := true

# Cooldown tracking with start time
var attack1_cooldown_start := 0.0
var attack2_cooldown_start := 0.0
var dash_attack_cooldown_start := 0.0

var facing := 1
var dash_dir := 1
var air_dash_available := true

var last_wall_jump_side := 0

# HP system
var max_hp: int = 5
var hp: int = 5
var invincible: bool = false
const IFRAME_TIME: float = 0.4

# hit-stun / get-hit animation
const HIT_STUN_TIME: float = 0.18
var is_hitstunned: bool = false

# Player attack damage
const ATTACK1_DAMAGE: int = 1
const ATTACK1_HIT_START: float = 0.08
const ATTACK1_HIT_DURATION: float = 0.12

const ATTACK2_DAMAGE: int = 2
const ATTACK2_HIT_START: float = 0.10
const ATTACK2_HIT_DURATION: float = 0.14

const DASH_ATTACK_DAMAGE: int = 3
const DASH_ATTACK_HIT_START: float = 0.05
const DASH_ATTACK_HIT_DURATION: float = 0.20

var attack1_active: bool = false
var attack2_active: bool = false
var dash_attack_active: bool = false

var attack1_already_hit: Dictionary = {} # instance_id -> true
var attack2_already_hit: Dictionary = {} # instance_id -> true
var dash_attack_already_hit: Dictionary = {} # instance_id -> true

var spawn_position: Vector2 = Vector2.ZERO
var dead: bool = false

func _ready() -> void:
	add_to_group("player")

	# Connect animation finished so attacks end (attack anims must be Loop OFF)
	animated_sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)

	# Hitboxes off by default
	attack_1_hit_box.monitoring = false
	attack_2_hit_box.monitoring = false
	dash_attack_hit_box.monitoring = false

	attack_1_hit_box.body_entered.connect(_on_attack1_hit_box_body_entered)
	attack_2_hit_box.body_entered.connect(_on_attack2_hit_box_body_entered)
	dash_attack_hit_box.body_entered.connect(_on_dash_attack_hit_box_body_entered)

	# IMPORTANT: flip the whole attack rig with facing
	attack_root.scale.x = facing
	
	spawn_position = global_position

func _physics_process(delta: float) -> void:
	if dead:
		return
	
	# If hit-stunned, lock control briefly and don't run normal logic
	if is_hitstunned:
		velocity.x = 0
		move_and_slide()
		return

	# Reset air dash when you touch the floor
	if is_on_floor():
		air_dash_available = true
		last_wall_jump_side = 0

	# Gravity (skip during dash if you want a flat dash)
	if not is_on_floor() and not is_dashing:
		velocity += get_gravity() * delta

	var direction := Input.get_axis("move_left", "move_right")

	# Update facing when player inputs direction (not during dash)
	if direction != 0 and not is_dashing:
		facing = 1 if direction > 0 else -1
		animated_sprite.flip_h = (facing == -1)
		attack_root.scale.x = facing # NEW

	# DASH start
	if Input.is_action_just_pressed("dash") and can_dash and not is_attacking and not is_dashing:
		if is_on_floor():
			start_dash()
		else:
			if air_dash_available:
				air_dash_available = false
				start_dash()

	# DASH ATTACK (attack button during dash)
	if is_dashing and Input.is_action_just_pressed("attack1") and not is_attacking and dash_attack_ready:
		is_attacking = true
		animated_sprite.play("dash_attack")
		dash_attack.play()
		_start_dash_attack_hit_window()
		_start_dash_attack_cooldown()
		_notify_enemies_attacking(true)

	# DASH active
	if is_dashing:
		velocity.y = 0
		velocity.x = dash_dir * DASH_SPEED
		move_and_slide()
		return

	# Attacks
	if Input.is_action_just_pressed("attack1") and not is_attacking and can_attack and attack1_ready:
		is_attacking = true
		animated_sprite.play("attack1")
		sword_slash_1.play()
		_start_attack1_hit_window()
		_start_attack1_cooldown()
		_notify_enemies_attacking(true)
	elif Input.is_action_just_pressed("attack2") and not is_attacking and can_attack and attack2_ready:
		is_attacking = true
		animated_sprite.play("attack2")
		sword_slash_2.play()
		_start_attack2_hit_window()
		_start_attack2_cooldown()
		_notify_enemies_attacking(true)

	# While attacking: stop movement and DO NOT run other animation logic
	if is_attacking:
		velocity.x = 0
		move_and_slide()
		return

	# Wall slide
	if not is_on_floor() and is_on_wall() and velocity.y > WALL_SLIDE_SPEED:
		velocity.y = WALL_SLIDE_SPEED

	# Jump / Wall jump
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif is_on_wall():
			var n := get_wall_normal()

			var wall_side := 0
			if n.x > 0.0:
				wall_side = 1
			elif n.x < 0.0:
				wall_side = -1

			if wall_side != 0 and (last_wall_jump_side == 0 or wall_side != last_wall_jump_side):
				velocity.y = WALL_JUMP_VELOCITY
				velocity.x = n.x * WALL_JUMP_PUSH
				last_wall_jump_side = wall_side

				facing = 1 if velocity.x > 0 else -1
				animated_sprite.flip_h = (facing == -1)
				attack_root.scale.x = facing # NEW

	# Animations (normal only)
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
			walk.play()

	# Movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# Safety: keep hitboxes disabled when not in hit window
	if not attack1_active:
		attack_1_hit_box.monitoring = false
	if not attack2_active:
		attack_2_hit_box.monitoring = false
	if not dash_attack_active:
		dash_attack_hit_box.monitoring = false

	move_and_slide()
	queue_redraw()

func _draw() -> void:
	# Draw health bar above the player
	var bar_position = Vector2(-HEALTH_BAR_WIDTH / 2, HEALTH_BAR_OFFSET_Y)
	
	# Draw background (dark red)
	draw_rect(Rect2(bar_position, Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)), Color.DARK_RED)
	
	# Draw health (green)
	var health_percentage = float(hp) / float(max_hp)
	var health_width = HEALTH_BAR_WIDTH * health_percentage
	draw_rect(Rect2(bar_position, Vector2(health_width, HEALTH_BAR_HEIGHT)), Color.GREEN)
	
	# Draw border (white)
	draw_rect(Rect2(bar_position, Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)), Color.WHITE, false, 2.0)

func _notify_enemies_attacking(attacking: bool) -> void:
	# Tell all enemies in the "enemy" group that we're attacking
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_method("set_player_attacking"):
			enemy.set_player_attacking(attacking)

func _start_attack1_cooldown() -> void:
	attack1_ready = false
	attack1_cooldown_start = Time.get_ticks_msec() / 1000.0
	await get_tree().create_timer(ATTACK1_COOLDOWN).timeout
	attack1_ready = true

func _start_attack2_cooldown() -> void:
	attack2_ready = false
	attack2_cooldown_start = Time.get_ticks_msec() / 1000.0
	await get_tree().create_timer(ATTACK2_COOLDOWN).timeout
	attack2_ready = true

func _start_dash_attack_cooldown() -> void:
	dash_attack_ready = false
	dash_attack_cooldown_start = Time.get_ticks_msec() / 1000.0
	await get_tree().create_timer(DASH_ATTACK_COOLDOWN).timeout
	dash_attack_ready = true

func _start_attack1_hit_window() -> void:
	attack1_already_hit.clear()
	attack1_active = false
	attack_1_hit_box.monitoring = false

	await get_tree().create_timer(ATTACK1_HIT_START).timeout
	if not is_attacking or animated_sprite.animation != "attack1":
		return

	attack1_active = true
	attack_1_hit_box.monitoring = true

	await get_tree().create_timer(ATTACK1_HIT_DURATION).timeout
	attack1_active = false
	attack_1_hit_box.monitoring = false

func _start_attack2_hit_window() -> void:
	attack2_already_hit.clear()
	attack2_active = false
	attack_2_hit_box.monitoring = false

	await get_tree().create_timer(ATTACK2_HIT_START).timeout
	if not is_attacking or animated_sprite.animation != "attack2":
		return

	attack2_active = true
	attack_2_hit_box.monitoring = true

	await get_tree().create_timer(ATTACK2_HIT_DURATION).timeout
	attack2_active = false
	attack_2_hit_box.monitoring = false

func _start_dash_attack_hit_window() -> void:
	dash_attack_already_hit.clear()
	dash_attack_active = false
	dash_attack_hit_box.monitoring = false

	await get_tree().create_timer(DASH_ATTACK_HIT_START).timeout
	if not is_attacking or animated_sprite.animation != "dash_attack":
		return

	dash_attack_active = true
	dash_attack_hit_box.monitoring = true

	await get_tree().create_timer(DASH_ATTACK_HIT_DURATION).timeout
	dash_attack_active = false
	dash_attack_hit_box.monitoring = false

func _on_attack1_hit_box_body_entered(body: Node) -> void:
	if not attack1_active:
		return
	if not body.has_method("take_damage"):
		return

	var id := body.get_instance_id()
	if attack1_already_hit.has(id):
		return

	attack1_already_hit[id] = true
	body.take_damage(ATTACK1_DAMAGE)

func _on_attack2_hit_box_body_entered(body: Node) -> void:
	if not attack2_active:
		return
	if not body.has_method("take_damage"):
		return

	var id := body.get_instance_id()
	if attack2_already_hit.has(id):
		return

	attack2_already_hit[id] = true
	body.take_damage(ATTACK2_DAMAGE)

func _on_dash_attack_hit_box_body_entered(body: Node) -> void:
	if not dash_attack_active:
		return
	if not body.has_method("take_damage"):
		return

	var id := body.get_instance_id()
	if dash_attack_already_hit.has(id):
		return

	dash_attack_already_hit[id] = true
	body.take_damage(DASH_ATTACK_DAMAGE)

func start_dash() -> void:
	is_dashing = true
	can_dash = false
	dash_dir = facing

	animated_sprite.play("dash")
	animated_sprite.flip_h = (dash_dir == -1)

	velocity.y = 0
	velocity.x = dash_dir * DASH_SPEED

	await get_tree().create_timer(DASH_TIME).timeout
	is_dashing = false
	
	velocity.x = 0
	velocity.y = 0

	get_tree().create_timer(DASH_COOLDOWN).timeout.connect(func ():
		can_dash = true
	)

func _on_animated_sprite_2d_animation_finished() -> void:
	if animated_sprite.animation == "attack1" or animated_sprite.animation == "attack2" or animated_sprite.animation == "dash_attack":
		is_attacking = false
		_notify_enemies_attacking(false)

		attack1_active = false
		attack2_active = false
		dash_attack_active = false
		attack_1_hit_box.monitoring = false
		attack_2_hit_box.monitoring = false
		dash_attack_hit_box.monitoring = false

func take_damage(amount: int) -> void:
	if invincible:
		return

	hp = max(hp - amount, 0)
	print("Player took damage:", amount, "HP:", hp, "/", max_hp)
	queue_redraw()

	if hp <= 0:
		die()
		return

	# Cancel actions + disable hitboxes immediately
	is_attacking = false
	is_dashing = false
	attack1_active = false
	attack2_active = false
	dash_attack_active = false
	attack_1_hit_box.monitoring = false
	attack_2_hit_box.monitoring = false
	dash_attack_hit_box.monitoring = false
	_notify_enemies_attacking(false)

	# Play "hit" animation (if present)
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("hit"):
		animated_sprite.play("hit")

	# Apply i-frames + short stun
	invincible = true
	is_hitstunned = true

	await get_tree().create_timer(HIT_STUN_TIME).timeout
	is_hitstunned = false

	await get_tree().create_timer(IFRAME_TIME).timeout
	invincible = false

func die() -> void:
	dead = true
	Engine.time_scale = 1.0
	
	await get_tree().create_timer(1.0).timeout
	
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
