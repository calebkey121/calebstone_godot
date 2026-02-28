extends Node

var session_id: String = ""
var current_player: Dictionary = {}
var opposing_player: Dictionary = {}
var current_round: int = 0
var is_game_over: bool = false
var legal_actions: Array = []

func update_from_response(data: Dictionary) -> void:
	var raw = data
	if data.has("game_state"):
		data = data.get("game_state", {})
	current_player = data.get("current_player", {})
	opposing_player = data.get("opposing_player", {})
	current_round = data.get("round", data.get("current_round", 0))
	is_game_over = data.get("is_game_over", false)
	legal_actions = raw.get("legal_actions", [])
