extends Control

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/level1.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_restart_progress_pressed() -> void:
	var level = 1
	
	var file = FileAccess.open("res://level.txt", FileAccess.WRITE)
	
	if file == null:
		print("File open failed: ", FileAccess.get_open_error())
		return
	
	file.store_string(str(level))
	file.close()
	
	print("Saved level: ", level)
	print("File path: ", ProjectSettings.globalize_path("res://level.txt"))
	
	get_tree().change_scene_to_file("res://scenes/levels/level1.tscn")
