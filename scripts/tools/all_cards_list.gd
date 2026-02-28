extends Node

# Called when the node enters the scene tree for the first time.
func _ready():
	if CardLibrary.is_loaded:
		_populate_from_library()
	else:
		CardLibrary.card_library_loaded.connect(_populate_from_library)
		_populate_from_decklists()


func _populate_from_library():
	$AllCards.clear()
	var index := 0
	for card_id in CardLibrary.cards.keys():
		var card: CardData = CardLibrary.cards[card_id]
		$AllCards.add_item(card.name)
		$AllCards.set_item_metadata(index, card_id)
		index += 1


func _populate_from_decklists():
	var names := {}
	var dir = DirAccess.open("res://decklists")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				var data = Tools.load_data_from_json("res://decklists/%s" % file_name)
				if typeof(data) == TYPE_DICTIONARY:
					for name in data.keys():
						names[name] = true
			file_name = dir.get_next()
		dir.list_dir_end()
	var sorted_names: Array = names.keys()
	sorted_names.sort()
	$AllCards.clear()
	for i in range(sorted_names.size()):
		var name = sorted_names[i]
		$AllCards.add_item(name)
		$AllCards.set_item_metadata(i, name)
