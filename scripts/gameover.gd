extends Control

func _on_try_again_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level1.tscn")

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	
