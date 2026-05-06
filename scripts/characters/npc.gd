extends CharacterBody2D

@onready var interaction_area = $InteractionArea
@onready var sprite = $sprite

var player_in_range = false
var is_talking = false

func _ready() -> void:
	add_to_group("npc")
	
	sprite.flip_h = true
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		sprite.play("speak")
		if player_in_range and not is_talking:
			get_tree().root.set_input_as_handled()
			is_talking = true
			
			var parent = get_parent()
			if parent and parent.has_method("_on_npc_interact"):
				parent._on_npc_interact()

func stop_talking() -> void:
	is_talking = false
