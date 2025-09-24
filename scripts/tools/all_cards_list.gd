extends Node

# Called when the node enters the scene tree for the first time.
func _ready():
	await CardLibrary.card_library_loaded
	for card_name in Tools.get_card_names():
		$AllCards.add_item(card_name)
