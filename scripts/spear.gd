extends CharacterBody2D

const GRAVITY := 800.0

var spear_damage: int = 2
var has_hit: bool = false
var lifetime: float = 5.0  # Spear disappears after 5 seconds
var spear_direction: int = 1  # 1 for right, -1 for left

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	add_to_group("projectile")
	
	# Setup hitbox
	hitbox.monitoring = true
	hitbox.monitorable = false
	hitbox.set_collision_layer_value(1, false)
	hitbox.set_collision_layer_value(2, false)
	hitbox.set_collision_mask_value(1, true)   # Detect player on layer 1
	hitbox.set_collision_mask_value(2, true)   # Collide with level on layer 2
	
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	
	# Set sprite direction based on spear_direction
	animated_sprite.flip_h = (spear_direction == -1)
	
	# Set initial velocity based on spear_direction
	velocity.x = spear_direction * 400.0
	
	# Auto-delete after lifetime
	await get_tree().create_timer(lifetime).timeout
	if not has_hit:
		queue_free()

func _physics_process(delta: float) -> void:
	if has_hit:
		return
	
	# Apply gravity
	velocity.y += GRAVITY * delta
	
	# Move spear
	move_and_slide()
	
	# Rotate spear based on velocity direction
	if velocity.length() > 0:
		rotation = velocity.angle()

func _on_hitbox_body_entered(body: Node) -> void:
	# Only hit player once
	if has_hit:
		return
	
	if body.is_in_group("player") and body.has_method("take_damage"):
		has_hit = true
		body.take_damage(spear_damage)
		print("Spear hit player for ", spear_damage, " damage!")
		queue_free()
	# Also stick to level/walls
	elif body.is_in_group("level") or body.name == "TileMap":
		has_hit = true
		# Stop moving and stay embedded in wall/ground
		set_physics_process(false)
		# Wait a bit then disappear
		await get_tree().create_timer(2.0).timeout
		queue_free()
