extends Node

# Singleton to track all active enemies and handle despawn/respawn
var active_enemies: Array = []

func _ready() -> void:
	# Make this node persistent or recreate it each scene
	pass

func register_enemy(enemy: Node) -> void:
	"""Register an enemy when it spawns"""
	if enemy not in active_enemies:
		active_enemies.append(enemy)

func despawn_all_enemies() -> void:
	"""Despawn all active enemies"""
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()

func _on_player_died() -> void:
	"""Called when player dies"""
	despawn_all_enemies()
