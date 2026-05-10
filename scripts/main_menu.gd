extends Control

func _on_start_pressed() -> void:
	if FileAccess.file_exists("user://level.txt"):
		var file = FileAccess.open("user://level.txt", FileAccess.READ)
		var level = int(file.get_as_text())
		file.close()
		if level == 0:
			get_tree().change_scene_to_file("res://scenes/levels/opening_cinematic.tscn")
		elif level == 1:
			get_tree().change_scene_to_file("res://scenes/levels/level1.tscn")
		elif level == 2:
			get_tree().change_scene_to_file("res://scenes/levels/level2.tscn")
		elif level == 3:
			get_tree().change_scene_to_file("res://scenes/levels/level3.tscn")
		elif level == 4:
			get_tree().change_scene_to_file("res://scenes/levels/level4.tscn")
		else:
			print("Invalid level: ", level)
		print("Loaded level: ", level)
	else:
		print("No level file found")
		get_tree().change_scene_to_file("res://scenes/levels/opening_cinematic.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_restart_progress_pressed() -> void:
	var level = 0
	
	var file = FileAccess.open("res://level.txt", FileAccess.WRITE)
	
	if file == null:
		print("File open failed: ", FileAccess.get_open_error())
		return
	
	file.store_string(str(level))
	file.close()
	
	print("Saved level: ", level)
	print("File path: ", ProjectSettings.globalize_path("res://level.txt"))
	
	get_tree().change_scene_to_file("res://scenes/levels/opening_cinematic.tscn")
