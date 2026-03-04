extends Node

var session_id: String = ""
var current_player: Dictionary = {}
var opposing_player: Dictionary = {}
var current_round: int = 0
var is_game_over: bool = false
var legal_actions: Array = []
var local_player_id: String = "p1"
var active_player_id: String = ""
var result: String = "in_progress"
var status: String = ""

func update_from_response(data: Dictionary) -> void:
	var raw = data
	if data.has("game_state"):
		data = data.get("game_state", {})

	var wire_current: Dictionary = data.get("current_player", {})
	var wire_opposing: Dictionary = data.get("opposing_player", {})
	var wire_current_id: String = wire_current.get("player_id", "")
	var wire_opposing_id: String = wire_opposing.get("player_id", "")

	# Normalize to local perspective so UI never flips boards/hands based on turn ownership.
	if wire_current_id == local_player_id:
		current_player = wire_current
		opposing_player = wire_opposing
	elif wire_opposing_id == local_player_id:
		current_player = wire_opposing
		opposing_player = wire_current
	else:
		# Fallback for missing/legacy IDs.
		current_player = wire_current
		opposing_player = wire_opposing

	current_round = data.get("round", data.get("current_round", 0))
	active_player_id = data.get("active_player_id", wire_current_id)
	status = raw.get("status", "")
	result = raw.get("result", "in_progress")
	is_game_over = data.get("is_game_over", false) or result != "in_progress" or status == "finished"
	legal_actions = raw.get("legal_actions", [])
