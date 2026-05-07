extends Label

var text_credits = "THANK YOU FOR PLAYING

A Game By

Game Design

Programming

Art & UI Design

Music & Sound Effects

Special Thanks

Made with Godot Engine

THE END"

func _ready() -> void:
	scroll_text(text_credits)

func scroll_text(input_text:String)-> void:
	visible_characters = 0
	text = input_text
	
	for i in text.length():
		visible_characters +=4
		await get_tree().create_timer(0.1).timeout
