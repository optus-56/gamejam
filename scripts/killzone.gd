extends Area2D

@onready var timer: Timer = $Timer
var player_body: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	timer.timeout.connect(_on_timer_timeout)
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("die"):
		player_body = body
		Engine.time_scale = 0
		timer.start()

func _on_timer_timeout() -> void:
	Engine.time_scale = 1.0
	if player_body != null:
		player_body.die()
