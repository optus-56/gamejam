extends Control

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/opening_cinematic.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
