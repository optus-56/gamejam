extends CharacterBody2D

const SPEED := 100
const ATTACK_DAMAGE := 1
const DEATH_DAMAGE := 3
const ATTACK_COOLDOWN := 0.4
const GRAVITY := 800.0
const ATTACK_RANGE := 50.0  # Distance to trigger attack

# Normal attack hit frame(s) (0-based)
const HIT_FRAME: Array[int] = [9, 10]

const DEATH_HIT_FRAME: Array[int] = [12, 13, 14, 15, 16, 17]

# Health bar
const HEALTH_BAR_WIDTH := 40
const HEALTH_BAR_HEIGHT := 4
const HEALTH_BAR_OFFSET_Y := -62

# HP + reactions
var max_hp: int = 6
var hp: int = 3
var dead: bool = false

const HURT_LOCK_TIME: float = 0.1
var is_hurt: bool = false

var can_attack: bool = true
var is_attacking: bool = false

# one-hit gates
var did_hit_this_attack: bool = false
var did_death_damage: bool = false

var player: Node2D = null
var player_in_hitbox: bool = false
var hitbox_target: Node = null

var is_falling: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detect: Area2D = $Detect

@onready var attack_1_hitbox: Area2D = $Attack1Hitbox
@onready var attack_2_hitbox: Area2D = $Attack2Hitbox

func _ready() -> void:
	add_to_group("enemy")

	# --- Setup hitboxes (both OFF by default; enabled only during the animation) ---
	for hitbox in [attack_1_hitbox, attack_2_hitbox]:
		hitbox.monitoring = false
		hitbox.monitorable = false
		hitbox.set_collision_layer_value(1, false)
		hitbox.set_collision_layer_value(2, false)
		# player on layer 1
		hitbox.set_collision_mask_value(1, true)
		hitbox.set_collision_mask_value(2, false)
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.body_exited.connect(_on_hitbox_body_exited)

	# --- Setup detect area (detect player on layer 1) ---
	detect.monitoring = true
	detect.monitorable = false
	detect.set_collision_layer_value(1, false)
	detect.set_collision_layer_value(2, false)
	detect.set_collision_mask_value(1, true)
	detect.set_collision_mask_value(2, false)
	detect.body_entered.connect(_on_detect_body_entered)
	detect.body_exited.connect(_on_detect_body_exited)

	# --- Body collision: enemy on layer 2, collides with level on layer 2 ---
	set_collision_layer_value(2, true)
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, true)
	set_collision_mask_value(1, false)

	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)

	animated_sprite.flip_h = true

func _physics_process(delta: float) -> void:
	if dead:
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		is_falling = true
		if not is_attacking:
			animated_sprite.play("fall")
	else:
		is_falling = false

	# Hurt lock
	if is_hurt:
		velocity.x = 0.0
		move_and_slide()
		return

	# While attacking, don't chase
	if is_attacking:
		velocity.x = 0.0
		move_and_slide()
		return

	# Attack if player is detected AND close enough
	if player != null and can_attack and not is_attacking:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		if distance_to_player < ATTACK_RANGE:
			_start_attack1()
			move_and_slide()
			return

	# Otherwise chase player if detected
	if player != null:
		var dx := player.global_position.x - global_position.x
		var dir := signf(dx) # -1, 0, 1

		velocity.x = dir * SPEED

		if dir != 0.0:
			animated_sprite.flip_h = player.global_position.x < global_position.x
			_update_hitbox_position()

		animated_sprite.play("run" if dir != 0.0 else "idle")
	else:
		velocity.x = 0.0
		animated_sprite.play("idle")

	move_and_slide()

func _draw() -> void:
	var bar_position = Vector2(-HEALTH_BAR_WIDTH / 2, HEALTH_BAR_OFFSET_Y)
	draw_rect(Rect2(bar_position, Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)), Color.DARK_RED)

	var health_percentage = float(hp) / float(max_hp)
	var health_width = HEALTH_BAR_WIDTH * health_percentage
	draw_rect(Rect2(bar_position, Vector2(health_width, HEALTH_BAR_HEIGHT)), Color.GREEN)

	draw_rect(Rect2(bar_position, Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)), Color.WHITE, false, 1.0)

func _start_attack1() -> void:
	if is_attacking or not can_attack or dead or is_hurt:
		return

	is_attacking = true
	can_attack = false
	did_hit_this_attack = false

	# Face player
	if player != null:
		animated_sprite.flip_h = player.global_position.x < global_position.x
		_update_hitbox_position()

	# Enable ONLY attack1 hitbox
	_disable_all_hitboxes()
	attack_1_hitbox.monitoring = true
	attack_1_hitbox.monitorable = true

	animated_sprite.play("attack")

func _start_death_attack2() -> void:
	# prevent re-entry
	if dead:
		return
	dead = true

	is_attacking = true
	can_attack = false
	is_hurt = false

	did_hit_this_attack = false
	did_death_damage = false

	# Stop moving/chasing
	velocity = Vector2.ZERO
	set_physics_process(true)

	# Enable ONLY attack2 hitbox
	_disable_all_hitboxes()
	attack_2_hitbox.monitoring = true
	attack_2_hitbox.monitorable = true

	animated_sprite.play("death")

func _disable_all_hitboxes() -> void:
	for hitbox in [attack_1_hitbox, attack_2_hitbox]:
		hitbox.monitoring = false
		hitbox.monitorable = false

func _update_hitbox_position() -> void:
	var scale_value := -1.0 if animated_sprite.flip_h else 1.0
	attack_1_hitbox.scale.x = scale_value
	attack_2_hitbox.scale.x = scale_value

func _on_detect_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body as Node2D

func _on_detect_body_exited(body: Node) -> void:
	if body == player:
		player = null

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
	var anim := animated_sprite.animation
	if not is_attacking:
		return

	# --- Normal attack damage ---
	if anim == "attack":
		if dead or is_hurt:
			return
		if did_hit_this_attack:  # Already hit this attack, don't hit again
			return
		if animated_sprite.frame in HIT_FRAME:
			did_hit_this_attack = true
			if player_in_hitbox and hitbox_target != null and is_instance_valid(hitbox_target):
				hitbox_target.take_damage(ATTACK_DAMAGE)

	# --- Death damage ---
	elif anim == "death":
		if did_death_damage:
			return
		if animated_sprite.frame in DEATH_HIT_FRAME:
			did_death_damage = true
			if player_in_hitbox and hitbox_target != null and is_instance_valid(hitbox_target):
				hitbox_target.take_damage(DEATH_DAMAGE)

func _on_animation_finished() -> void:
	var anim := animated_sprite.animation

	# End of normal attack
	if anim == "attack":
		is_attacking = false
		_disable_all_hitboxes()
		player_in_hitbox = false
		hitbox_target = null

		get_tree().create_timer(ATTACK_COOLDOWN).timeout.connect(func ():
			if dead:
				return
			can_attack = true
		)

	# End of death animation: cleanup + free
	elif anim == "death":
		_disable_all_hitboxes()
		detect.monitoring = false
		detect.monitorable = false

		# Optional: tell your scene
		if get_tree().current_scene != null and get_tree().current_scene.has_method("mob_died"):
			get_tree().current_scene.mob_died()

		queue_free()

func take_damage(amount: int) -> void:
	# if already in death sequence, ignore further hits
	if dead:
		return

	hp = max(hp - amount, 0)
	queue_redraw()

	if hp <= 0:
		# start death-damage animation
		_start_death_attack2()
		return

	# Hurt reaction
	is_hurt = true
	is_attacking = false
	can_attack = false
	did_hit_this_attack = true
	velocity.x = 0.0

	_disable_all_hitboxes()

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("hit"):
		animated_sprite.play("hit")

	await get_tree().create_timer(HURT_LOCK_TIME).timeout
	is_hurt = false
	if not dead:
		can_attack = true
