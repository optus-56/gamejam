extends CharacterBody2D

const SPEED := 100
const DAMAGE := 2
const ATTACK_COOLDOWN := 0.4

# Damage will happen when the "attack" animation reaches this frame (0-based)
const HIT_FRAME: Array[int] = [7, 8, 9]

# Health bar
const HEALTH_BAR_WIDTH := 40
const HEALTH_BAR_HEIGHT := 4
const HEALTH_BAR_OFFSET_Y := -50 # Offset above the mob

# HP + reactions
var max_hp: int = 6
var hp: int = 6
var dead: bool = false

const HURT_LOCK_TIME: float = 0.1
var is_hurt: bool = false

var can_attack: bool = true
var is_attacking: bool = false
var did_hit_this_attack: bool = false

var player: Node2D = null
var player_in_hitbox: bool = false
var hitbox_target: Node = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var detect: Area2D = $Detect
@onready var sfx: AudioStreamPlayer2D = $SFX

func _ready() -> void:
	hitbox.monitorable = false
	detect.monitorable = false
	
	set_collision_layer_value(2, true)
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, true)  # Can collide with level/walls on layer 2
	set_collision_mask_value(1, false)
	
	detect.body_entered.connect(_on_detect_body_entered)
	detect.body_exited.connect(_on_detect_body_exited)

	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.body_exited.connect(_on_hitbox_body_exited)

	animated_sprite.frame_changed.connect(_on_frame_changed)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	animated_sprite.flip_h = true

func _physics_process(_delta: float) -> void:
	if dead:
		return

	# While hurt: stop and don't attack/chase
	if is_hurt:
		velocity.x = 0.0
		move_and_slide()
		return

	if is_attacking:
		velocity.x = 0.0
		move_and_slide()
		return

	# If player is in hitbox and we're able to attack, begin attack immediately.
	if player_in_hitbox and can_attack:
		_start_attack()
		velocity.x = 0.0
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

		animated_sprite.play("walk" if dir != 0.0 else "idle")
	else:
		velocity.x = 0.0
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
		animated_sprite.flip_h = player.global_position.x < global_position.x
		_update_hitbox_position()

	animated_sprite.play("attack")
	sfx.play()

func _update_hitbox_position() -> void:
	# Flip hitbox scale to match sprite direction
	if animated_sprite.flip_h:
		hitbox.scale.x = -1.0  # Facing left
	else:
		hitbox.scale.x = 1.0   # Facing right

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
	# Only apply damage during the attack animation
	if animated_sprite.animation != "attack":
		return
	if not is_attacking or did_hit_this_attack:
		return
	if dead or is_hurt:
		return

	if animated_sprite.frame in HIT_FRAME:
		did_hit_this_attack = true

		# Deal damage only if still in range *at the hit frame*
		if player_in_hitbox and hitbox_target != null and is_instance_valid(hitbox_target):
			hitbox_target.take_damage(DAMAGE)

func _on_animation_finished() -> void:
	# Only react to the end of the attack animation
	if animated_sprite.animation != "attack":
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
	print("Ninja HP:", hp, "/", max_hp)
	queue_redraw()

	if hp <= 0:
		die()
		return

	# Hurt reaction (play "hit", briefly lock movement/attacks)
	is_hurt = true
	is_attacking = false
	can_attack = false
	did_hit_this_attack = true # prevents a pending hit frame from landing after being hurt
	velocity.x = 0.0

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

	hitbox.monitoring = false
	detect.monitoring = false
	hitbox.monitorable = false
	detect.monitorable = false

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished

	get_tree().current_scene.mob_died()

	queue_free()
