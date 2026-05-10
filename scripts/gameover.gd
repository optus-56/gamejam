extends Control

@onready var try_again: TextureButton = $VBoxContainer2/Try_again
@onready var quit: TextureButton = $VBoxContainer2/quit

func _ready():
	try_again.pressed.connect(_on_try_again_pressed)
	quit.pressed.connect(_on_quit_pressed)

func _on_try_again_pressed():
	if Global.last_level_path != "":
		get_tree().change_scene_to_file(Global.last_level_path)
	else:
		get_tree().change_scene_to_file("res://scenes/levels/opening_cinematic.tscn")

func _on_quit_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
