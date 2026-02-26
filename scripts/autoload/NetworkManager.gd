extends Node

# API Endpoints
var api_endpoint: String = "http://127.0.0.1:5001"
func get_new_game_endpoint() -> String:
	return "%s/api/new_game" % [api_endpoint]
func get_load_game_endpoint(session_id: String) -> String:
	return "%s/api/game_state/%s" % [api_endpoint, session_id]
func get_all_sessions_endpoint() -> String:
	return "%s/api/game_state" % [api_endpoint]
func get_card_library_endpoint() -> String:
	return "%s/api/card_library" % [api_endpoint]

# Function to request starting a new game using the HTTPRequest passed in.
func new_game(http_request: HTTPRequest, p1_type: String, p2_type: String) -> void:
	var endpoint: String = get_new_game_endpoint()
	var payload = {
		"player1_controller": p1_type,
		"player2_controller": p2_type
	}
	var body = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	http_request.request(endpoint, headers, HTTPClient.METHOD_POST, body)
	
# Function to load a game session given a session id.
func load_game(http_request: HTTPRequest, session_id: String) -> void:
	var endpoint: String = get_load_game_endpoint(session_id)
	http_request.request(endpoint, [], HTTPClient.METHOD_GET)

# Function to load all available game sessions.
func get_all_sessions(http_request: HTTPRequest) -> void:
	var endpoint: String = get_all_sessions_endpoint()
	http_request.request(endpoint, [], HTTPClient.METHOD_GET)

func get_card_library(http_request: HTTPRequest) -> void:
	var endpoint: String = get_card_library_endpoint()
	http_request.request(endpoint, [], HTTPClient.METHOD_GET)

func get_action_endpoint(session_id: String) -> String:
	return "%s/api/action/%s" % [api_endpoint, session_id]

# Submit a game action (play_card, attack, end_turn) for the current session.
func submit_action(http_request: HTTPRequest, session_id: String, action: Dictionary) -> void:
	var endpoint: String = get_action_endpoint(session_id)
	var body = JSON.stringify(action)
	var headers = ["Content-Type: application/json"]
	http_request.request(endpoint, headers, HTTPClient.METHOD_POST, body)
