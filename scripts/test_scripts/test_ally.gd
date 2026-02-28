extends Node

@onready var ally: Ally = $Ally
var current_card_name: String = ""

func _ready():
	$FrameList/Frames.item_selected.connect(_on_frame_list_item_selected)
	$AllCardsList/AllCards.item_selected.connect(_on_card_list_item_selected)
	_init_default_card()

func _init_default_card():
	await CardLibrary.card_library_loaded
	var list = $AllCardsList/AllCards
	if list.item_count > 0:
		list.select(0)
		_on_card_list_item_selected(0)

func _on_card_list_item_selected(index):
	var card_id = $AllCardsList/AllCards.get_item_metadata(index)
	if card_id == null:
		return
	current_card_name = card_id
	_apply_ally()

func _on_frame_list_item_selected(_index):
	_apply_ally()

func _apply_ally():
	if current_card_name == "":
		return
	var card_data: CardData = CardLibrary.cards.get(current_card_name)
	if card_data == null:
		card_data = CardData.new({
			"name": current_card_name,
			"attack": 0,
			"health": 0,
			"cost": 0,
			"text": ""
		})
	var data_dict = {
		"name": card_data.name,
		"attack": card_data.attack,
		"health": card_data.health,
		"cost": card_data.cost,
		"text": card_data.text
	}
	ally.setup(data_dict, 0, true)
	ally.set_selected(true)
