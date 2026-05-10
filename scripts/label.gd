extends Label

var text_credits = "THANK YOU FOR PLAYING OUR GAME

A Game By

Bijan Thapa

Samyak Maharjan

Prabin Thapa

THE END"

func _ready() -> void:
	scroll_text(text_credits)

func scroll_text(input_text:String)-> void:
	visible_characters = 0
	text = input_text
	
	for i in text.length():
		visible_characters +=4
		await get_tree().create_timer(0.1).timeout
