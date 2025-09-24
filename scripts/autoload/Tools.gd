extends Node

# Returns parsed json from file, as a dictionary
func load_data_from_json(file_path):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json = file.get_as_text()
		var data = JSON.parse_string(json)
		return data
	else:
		print("File not found: " + file_path)

func get_card_names():
	var card_names: Array[String]
	for card_name in CardLibrary.cards:
		card_names.append(card_name)
	return card_names

func get_card_data(card_name: String) -> CardData:
	var data = CardLibrary.cards.get(card_name)
	if data == null:
		data = CardLibrary.cards.get("default")
	return data

func get_frame_names():
	var frame_data = Tools.load_data_from_json("res://card_data/card_frames.json")
	var frame_names: Array[String]
	for frame_name in frame_data:
		frame_names.append(frame_name)
	return frame_names
