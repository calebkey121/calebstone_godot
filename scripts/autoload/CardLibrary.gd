extends Node

signal card_library_loaded

var cards: Dictionary = {}
var is_loaded := false

@onready var http_request: HTTPRequest = HTTPRequest.new()

func _ready():
	add_child(http_request)
	http_request.request_completed.connect(_on_response)
	var url = NetworkManager.get_card_library_endpoint()
	http_request.request(url)

func _on_response(result, response_code, headers, body):
	if response_code == 200:
		var parsed = JSON.parse_string(body.get_string_from_utf8())
		for card_data in parsed["cards"]:
			cards[card_data["card_id"]] = CardData.new(card_data)
		is_loaded = true
		emit_signal("card_library_loaded")
	else:
		push_error("CardLibrary failed to load: %s" % response_code)
