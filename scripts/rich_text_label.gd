extends RichTextLabel

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
	
	for i in get_parsed_text():
		visible_characters +=1
		await get_tree().create_timer(0.1).timeout
	
