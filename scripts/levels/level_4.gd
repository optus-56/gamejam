extends Node2D

var mobs_remaining: int = 0
@onready var label: Label = $Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.last_level_path = get_tree().current_scene.scene_file_path
	label.hide()
	mobs_remaining = $Mobs.get_child_count()
	print("Mobs to kill: ", mobs_remaining)

func mob_died() -> void: 
	mobs_remaining -= 1
	print("Mobs remaining: ", mobs_remaining)
	
	if mobs_remaining == 0:
		on_all_mobs_defeated()

func on_all_mobs_defeated():
	label.show()
	print("All mobs defeated!")
	$Door.open()
