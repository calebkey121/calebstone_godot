extends Node

# Cards
@onready var card: Card = $Card
@onready var card_data: CardData = CardData.new({})
# Called when the node enters the scene tree for the first time.
func _ready():
	$FrameList/Frames.item_selected.connect(_on_frame_list_item_selected)
	$AllCardsList/AllCards.item_selected.connect(_on_card_list_item_selected)

func update_card():
	CardManager.adjust_card(card, card_data)

# Buttons
func _on_card_list_item_selected(index):
	var meta = $AllCardsList/AllCards.get_item_metadata(index)
	var selected: CardData = CardLibrary.cards.get(meta)
	if selected == null:
		var name = $AllCardsList/AllCards.get_item_text(index)
		selected = CardData.new({
			"name": name,
			"attack": 0,
			"health": 0,
			"cost": 0,
			"text": ""
		})
	card_data = selected
	update_card()

func _on_frame_list_item_selected(index):
	update_card()
