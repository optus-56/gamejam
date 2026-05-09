extends Area2D

var is_open: bool = false
var player_inside: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func open():
	is_open = true

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_inside = false

func _process(_delta: float) -> void:
	if player_inside:
		if is_open:
			if Input.is_action_just_pressed("interact"):
				go_to_next_level()

func go_to_next_level():
	
	var level = 4
	
	var file = FileAccess.open("user://level.txt", FileAccess.WRITE)
	
	if file == null:
		print("File open failed: ", FileAccess.get_open_error())
		return
	
	file.store_string(str(level))
	file.close()
	
	print("Saved level: ", level)
	print("File path: ", ProjectSettings.globalize_path("user://level.txt"))
	
	get_tree().change_scene_to_file("res://scenes/levels/level4.tscn")
