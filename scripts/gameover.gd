extends Control

func _on_try_again_pressed() -> void:

	if FileAccess.file_exists("user://level.txt"):
		var file = FileAccess.open("user://level.txt", FileAccess.READ)
		var level = int(file.get_as_text())
		file.close()
		if level == 1:
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
		get_tree().change_scene_to_file("res://scenes/levels/level1.tscn")

func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	
	get_tree().change_scene_to_file("res://scenes/levels/level1.tscn")
	
