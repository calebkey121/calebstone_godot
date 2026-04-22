extends Control

# Signal for transitioning to the game scene
signal game_started(game_data)

@onready var new_game_button = $NewGameButton
@onready var quit_button = $QuitButton
@onready var http_request = $HTTPRequest
@onready var session_list = $SessionListNode/SessionList
var current_request: String

var player1_controller: String = "human"
var player2_controller: String = "random"

func _ready():
	# Connect button signals
	new_game_button.pressed.connect(_on_new_game_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	# Connect HTTPRequest signals
	http_request.request_completed.connect(_on_http_request_completed)
	
	# Get any already running sessions on the server
	current_request = "get_all_sessions"
	NetworkManager.get_all_sessions($HTTPRequest)

# Quit game button functionality
func _on_quit_button_pressed():
	get_tree().quit()

# Start game button functionality
func _on_new_game_button_pressed():
	current_request = "new_game"
	NetworkManager.new_game($HTTPRequest, player1_controller, player2_controller)

# Callback for when the HTTP request completes
func _on_http_request_completed(_result, response_code, _headers, body):
	if response_code == 200:  # HTTP OK
		var response = JSON.parse_string(body.get_string_from_utf8())
		if current_request == "new_game":
			var session_id = response["session_id"]
			GameState.session_id = session_id
			session_list.add_item(session_id)
			# Refresh the full session list to show the new game
			current_request = "get_all_sessions"
			NetworkManager.get_all_sessions($HTTPRequest)
		elif current_request == "load_game":
			# Game state is stored; transition to game scene
			_load_game_scene()
		elif current_request == "get_all_sessions":
			session_list.clear()
			for session in response:
				session_list.add_item(session)
	else:
		print("Failed to start game. HTTP Code:", response_code)

# Transition to the game scene
func _load_game_scene():
	var err = get_tree().change_scene_to_file("res://scenes/game.tscn")
	if err != OK:
		push_error("Failed to change to Menu scene: %s" % err)

func _on_session_list_item_selected(index):
	GameState.session_id = session_list.get_item_text(index)

func _on_load_game_button_pressed():
	if GameState.session_id == "":
		print("No session selected.")
		return
	current_request = "load_game"
	NetworkManager.load_game($HTTPRequest, GameState.session_id)

func _on_player_1_controller_item_selected(index):
	player1_controller = $Player1ControllerNode/Player1Controller.get_item_text(index)

func _on_player_2_controller_item_selected(index):
	player2_controller = $Player2ControllerNode/Player2Controller.get_item_text(index)

func _on_refresh_sessions_button_pressed():
	# Get any already running sessions on the server
	current_request = "get_all_sessions"
	NetworkManager.get_all_sessions($HTTPRequest)
