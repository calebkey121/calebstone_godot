extends Control

@onready var new_game_button = $NewGameButton
@onready var http_request = $HTTPRequest
var current_request: String

var player1_controller: String = "human"
var player2_controller: String = "random"

func _ready():
	new_game_button.pressed.connect(_on_new_game_button_pressed)
	http_request.request_completed.connect(_on_http_request_completed)

func _on_new_game_button_pressed():
	current_request = "new_game"
	NetworkManager.new_game($HTTPRequest, player1_controller, player2_controller)

func _on_http_request_completed(_result, response_code, _headers, body):
	if response_code == 200:  # HTTP OK
		var response = JSON.parse_string(body.get_string_from_utf8())
		if current_request == "new_game":
			var session_id = response["session_id"]
			GameState.session_id = session_id
			_load_game_scene()
	else:
		print("Failed to start game. HTTP Code:", response_code)

func _load_game_scene():
	var err = get_tree().change_scene_to_file("res://scenes/game.tscn")
	if err != OK:
		push_error("Failed to change to Menu scene: %s" % err)
