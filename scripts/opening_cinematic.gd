# opening_cinematic.gd
extends Node2D

@onready var dialogue_label = $DialogueBox/PanelContainer/VBoxContainer/DialogueLabel
@onready var dialogue_box = $DialogueBox
@onready var player = $Player
@onready var npc = $npc

var dialogue_index = 0
var is_dialogue_active = false
var is_typing = false
var dialogue_started = false

var dialogues = [
	"Welcome, chosen one. I am Meredith, keeper of the old ways.",
	"The kingdom is cursed. A darkness spreads across all lands.",
	"You have been chosen by the ancient magic to save us.",
	"Before you go, let me teach you how to survive.",
	"Press A or D to move LEFT and RIGHT.",
	"Press SPACE to JUMP.",
	"Press SHIFT to DASH - move quickly across the battlefield.",
	"Press MOUSE 1 to perform ATTACK 1 - your basic sword strike.",
	"Press MOUSE 2 to perform ATTACK 2 - a stronger, slower strike.",
	"During a DASH, press MOUSE 1 for a powerful DASH ATTACK.",
	"Remember: timing and precision will determine your victory.",
	"The curse grows stronger with each passing moment.",
	"Go now, brave warrior. The forest awaits.",
	"May the ancient magic guide your sword."
]

func _ready() -> void:
	dialogue_box.modulate.a = 0
	dialogue_index = 0
	
	if not player.is_in_group("player"):
		player.add_to_group("player")
	
	if not npc.is_in_group("npc"):
		npc.add_to_group("npc")

func _on_npc_interact() -> void:
	if not is_dialogue_active and not dialogue_started:
		dialogue_started = true
		dialogue_index = 0
		show_next_dialogue()
	elif not is_dialogue_active and not is_typing:
		show_next_dialogue()

func show_next_dialogue() -> void:
	if dialogue_index >= dialogues.size():
		await fade_out_and_transition()
		return
	
	is_dialogue_active = true
	
	var tween = create_tween()
	tween.tween_property(dialogue_box, "modulate:a", 1.0, 0.3)
	
	dialogue_label.text = dialogues[dialogue_index]
	
	await typewriter_effect(dialogues[dialogue_index])
	
	dialogue_index += 1

func typewriter_effect(text: String) -> void:
	is_typing = true
	dialogue_label.text = ""
	for char in text:
		dialogue_label.text += char
		await get_tree().create_timer(0.03).timeout
	is_typing = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and is_dialogue_active and not is_typing:
		get_tree().root.set_input_as_handled()
		
		is_dialogue_active = false
		
		var tween = create_tween()
		tween.tween_property(dialogue_box, "modulate:a", 0.0, 0.2)
		
		await tween.finished
		
		await get_tree().create_timer(0.3).timeout
		show_next_dialogue()

func fade_out_and_transition() -> void:
	var fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.anchor_right = 1.0
	fade.anchor_bottom = 1.0
	add_child(fade)
	
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 1.0)
	
	await tween.finished
	
	var level = 1
	
	var file = FileAccess.open("user://level.txt", FileAccess.WRITE)
	
	if file == null:
		print("File open failed: ", FileAccess.get_open_error())
		return
	
	file.store_string(str(level))
	file.close()
	
	print("Saved level: ", level)
	print("File path: ", ProjectSettings.globalize_path("user://level.txt"))
	
	get_tree().change_scene_to_file("res://scenes/levels/level1.tscn")
