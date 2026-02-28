extends Node2D

@onready var http_request = $HTTPRequest
@onready var player_hand: Hand = $Hand
@onready var player_board = $Board
@onready var enemy_board = $Board2
@onready var end_turn_button: Button = $HUDRoot/TopRightHUD/TopRightVBox/EndTurnButton
@onready var gold_label: Label = $HUDRoot/LeftBar/LeftBarVBox/PlayerResources/GoldLabel
@onready var income_label: Label = $HUDRoot/LeftBar/LeftBarVBox/PlayerResources/IncomeLabel
@onready var round_label: Label = $HUDRoot/TopRightHUD/TopRightVBox/RoundLabel
@onready var status_label: Label = $HUDRoot/TopRightHUD/TopRightVBox/StatusLabel
@onready var player_name_label: Label = $HUDRoot/LeftBar/LeftBarVBox/PlayerPortrait/PlayerPortraitVBox/PlayerNameLabel
@onready var player_hp_label: Label = $HUDRoot/LeftBar/LeftBarVBox/PlayerPortrait/PlayerPortraitVBox/PlayerHPLabel
@onready var enemy_name_label: Label = $HUDRoot/LeftBar/LeftBarVBox/EnemyPortrait/EnemyPortraitVBox/EnemyNameLabel
@onready var enemy_hp_label: Label = $HUDRoot/LeftBar/LeftBarVBox/EnemyPortrait/EnemyPortraitVBox/EnemyHPLabel
@onready var enemy_hand_label: Label = $HUDRoot/LeftBar/LeftBarVBox/EnemyInfo/EnemyHandLabel
@onready var enemy_gold_label: Label = $HUDRoot/LeftBar/LeftBarVBox/EnemyInfo/EnemyGoldLabel
@onready var game_over_overlay: PanelContainer = $HUDRoot/GameOverOverlay
@onready var game_over_sub_label: Label = $HUDRoot/GameOverOverlay/GameOverVBox/GameOverSubLabel
@onready var hover_popup: PanelContainer = $HUDRoot/HoverPopup
@onready var hover_name_label: Label = $HUDRoot/HoverPopup/HoverVBox/CardNameLabel
@onready var hover_cost_label: Label = $HUDRoot/HoverPopup/HoverVBox/CardCostLabel
@onready var hover_stats_label: Label = $HUDRoot/HoverPopup/HoverVBox/CardStatsLabel
@onready var hover_text_label: Label = $HUDRoot/HoverPopup/HoverVBox/CardTextLabel
@onready var opponent_hand: Hand = $Hand2

# Debug logging for API traffic
@export var api_debug := false
@export var debug_play_card_flow := true

var debug_action_inflight := false
var debug_pending_action: Dictionary = {}
var debug_pending_remove_index := -1

# Attack selection state
var selected_attacker: Card = null
var player_allies: Array = []  # Card nodes on player board
var enemy_allies: Array = []   # Card nodes on enemy board

# Prevent double-input while a request is in-flight
var waiting_for_server: bool = false

# Which HTTP response are we expecting
enum RequestType { LOAD_GAME, SUBMIT_ACTION, DEBUG_PRE_ACTION, DEBUG_POST_ACTION }
var current_request: RequestType = RequestType.LOAD_GAME


func _ready() -> void:
	http_request.request_completed.connect(_on_http_request_completed)
	CardManager.card_drag_ended.connect(_on_card_drag_ended)
	CardManager.card_hovered.connect(_on_card_hovered)
	CardManager.card_unhovered.connect(_on_card_unhovered)

	# Mark the player's board as a valid card drop zone
	var player_board_area = player_board.get_node_or_null("Area2D")
	if player_board_area:
		player_board_area.add_to_group("card_drop_area")

	# Load initial game state from server
	current_request = RequestType.LOAD_GAME
	NetworkManager.load_game(http_request, GameState.session_id)


# ─────────────────────────────────────────────
#  RENDERING
# ─────────────────────────────────────────────

func setup(data: Dictionary) -> void:
	GameState.update_from_response(data)
	waiting_for_server = false
	selected_attacker = null

	_rebuild_hand()
	_rebuild_boards()
	_rebuild_opponent_hand()
	_update_hud()

	if GameState.is_game_over:
		_show_game_over()


func _rebuild_hand() -> void:
	player_hand.sync_from_card_data(GameState.current_player.get("hand", []))


func _rebuild_boards() -> void:
	for ally in player_allies:
		ally.queue_free()
	player_allies.clear()

	for ally in enemy_allies:
		ally.queue_free()
	enemy_allies.clear()

	var player_army: Array = GameState.current_player.get("army", [])
	var enemy_army: Array = GameState.opposing_player.get("army", [])

	# Army index 0 is the hero — shown in HUD labels, still spawned on board for targeting
	for i in range(player_army.size()):
		var card: Card = _spawn_board_card(player_army[i], i, true)
		player_board.add_child(card)
		player_allies.append(card)
		card.position = Vector2((i - player_army.size() / 2.0 + 0.5) * 130, 0)
		card.anchor_position = card.position

	for i in range(enemy_army.size()):
		var card: Card = _spawn_board_card(enemy_army[i], i, false)
		enemy_board.add_child(card)
		enemy_allies.append(card)
		card.position = Vector2((i - enemy_army.size() / 2.0 + 0.5) * 130, 0)
		card.anchor_position = card.position


func _spawn_board_card(ally_data: Dictionary, index: int, is_player: bool) -> Card:
	var card_data = CardData.new(ally_data)
	var card: Card = CardManager.create_card(card_data)
	card.setup_board(ally_data, index, is_player)
	card.card_clicked.connect(_on_board_card_clicked)
	return card


func _rebuild_opponent_hand() -> void:
	var opponent_cards: Array = GameState.opposing_player.get("hand", [])
	opponent_hand.sync_from_card_data(opponent_cards)
	for card in opponent_hand.cards:
		card.set_face_down(true)




func _update_hud() -> void:
	var cp = GameState.current_player
	var op = GameState.opposing_player

	round_label.text = "Round %d" % GameState.current_round
	gold_label.text = "Gold: %d" % cp.get("gold", 0)
	income_label.text = "Income: %d" % cp.get("income", 0)

	var p1_hero = cp.get("hero", {})
	var p2_hero = op.get("hero", {})
	player_name_label.text = p1_hero.get("name", "You")
	player_hp_label.text = "HP: %d" % p1_hero.get("health", 0)
	enemy_name_label.text = p2_hero.get("name", "Enemy")
	enemy_hp_label.text = "HP: %d" % p2_hero.get("health", 0)

	var enemy_hand_count: int = op.get("hand", []).size()
	enemy_hand_label.text = "Hand: %d" % enemy_hand_count
	enemy_gold_label.text = "Gold: %d  /  Income: %d" % [
		op.get("gold", 0), op.get("income", 0)
	]

	if waiting_for_server:
		status_label.text = "Waiting..."
		status_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 1))
	else:
		status_label.text = "Your Turn"
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1))
	end_turn_button.disabled = waiting_for_server


# ─────────────────────────────────────────────
#  ACTIONS
# ─────────────────────────────────────────────

func _on_card_drag_ended(card: Card, drop_area) -> void:
	if drop_area == null or waiting_for_server:
		return
	if not drop_area.is_in_group("card_drop_area"):
		return

	var idx = player_hand.cards.find(card)
	if idx == -1:
		return
	var instance_id = ""
	if card and card.data:
		instance_id = card.data.instance_id
	if instance_id == "":
		push_error("Cannot play card: missing instance_id")
		return

	var action := {"type": "play_card", "card_instance_id": instance_id}

	if debug_play_card_flow and not debug_action_inflight:
		debug_action_inflight = true
		debug_pending_action = action
		debug_pending_remove_index = idx
		waiting_for_server = true
		end_turn_button.disabled = true
		status_label.text = "Waiting..."
		current_request = RequestType.DEBUG_PRE_ACTION
		NetworkManager.load_game(http_request, GameState.session_id)
		return

	# Remove card from hand visually; board will fully rebuild on server response
	if idx != -1:
		player_hand.remove_card(idx)
	_submit_action(action)


func _on_board_card_clicked(card: Card) -> void:
	if waiting_for_server:
		return

	if card.is_player_ally:
		# Selecting / deselecting a friendly attacker
		if selected_attacker == card:
			card.set_selected(false)
			selected_attacker = null
			_clear_target_highlights()
		elif card.can_attack:
			if selected_attacker:
				selected_attacker.set_selected(false)
			selected_attacker = card
			card.set_selected(true)
			_highlight_targets()
	else:
		# Clicking an enemy: perform attack if we have a selected attacker
		if selected_attacker != null:
			var attacker_iid = selected_attacker.data.instance_id if selected_attacker.data else ""
			var target_iid = card.data.instance_id if card.data else ""
			if attacker_iid == "" or target_iid == "":
				push_error("Cannot attack: missing instance_id")
				return
			selected_attacker.set_selected(false)
			selected_attacker = null
			_clear_target_highlights()
			_submit_action({
				"type": "attack",
				"attacker_id": attacker_iid,
				"target_id": target_iid
			})


func _highlight_targets() -> void:
	for enemy in enemy_allies:
		enemy.set_targetable(true)


func _clear_target_highlights() -> void:
	for enemy in enemy_allies:
		enemy.set_targetable(false)


func _on_end_turn_pressed() -> void:
	if waiting_for_server:
		return
	_submit_action({"type": "end_turn"})


func _submit_action(action: Dictionary) -> void:
	if api_debug:
		print("API action -> ", JSON.stringify(action))
	waiting_for_server = true
	end_turn_button.disabled = true
	status_label.text = "Waiting..."
	current_request = RequestType.SUBMIT_ACTION
	NetworkManager.submit_action(http_request, GameState.session_id, action)


# ─────────────────────────────────────────────
#  HTTP RESPONSE
# ─────────────────────────────────────────────

func _on_http_request_completed(_result, response_code, _headers, body) -> void:
	if api_debug:
		print("API response code -> ", response_code)
		print("API response body -> ", body.get_string_from_utf8())
	if response_code != 200:
		push_error("HTTP error: %d" % response_code)
		waiting_for_server = false
		if status_label:
			status_label.text = "Server error %d" % response_code
		end_turn_button.disabled = false
		return

	var response = JSON.parse_string(body.get_string_from_utf8())
	if response == null:
		push_error("Failed to parse server response")
		waiting_for_server = false
		return

	match current_request:
		RequestType.LOAD_GAME:
			var game_state = response.get("game_state", response)
			setup(game_state)
		RequestType.DEBUG_PRE_ACTION:
			print("gamestate_before:\n", body.get_string_from_utf8())
			if debug_pending_remove_index != -1 and debug_pending_remove_index < player_hand.cards.size():
				player_hand.remove_card(debug_pending_remove_index)
			debug_pending_remove_index = -1
			current_request = RequestType.SUBMIT_ACTION
			NetworkManager.submit_action(http_request, GameState.session_id, debug_pending_action)
		RequestType.SUBMIT_ACTION:
			# Action responses: { "status": "success", "game_state": {...} }
			if debug_action_inflight:
				print("playing card:\n", JSON.stringify(debug_pending_action))
				print("action_response:\n", body.get_string_from_utf8())
			var game_state = response.get("game_state", response)
			setup(game_state)
			if debug_action_inflight:
				current_request = RequestType.DEBUG_POST_ACTION
				NetworkManager.load_game(http_request, GameState.session_id)
		RequestType.DEBUG_POST_ACTION:
			print("gamestate_after:\n", body.get_string_from_utf8())
			debug_action_inflight = false
			debug_pending_action = {}
			debug_pending_remove_index = -1


# ─────────────────────────────────────────────
#  GAME OVER
# ─────────────────────────────────────────────

func _show_game_over() -> void:
	var winner = GameState.current_player.get("hero", {}).get("health", 0)
	game_over_sub_label.text = "You Win!" if winner > 0 else "You Lose!"
	game_over_overlay.visible = true
	end_turn_button.disabled = true


func _on_card_hovered(card: Card) -> void:
	if card == null or card.data == null:
		return
	if card.face_down:
		hover_popup.visible = false
		return
	hover_name_label.text = card.data.name
	hover_cost_label.text = "Cost: %d" % card.data.cost
	hover_stats_label.text = "ATK %d  •  HP %d" % [card.data.attack, card.data.health]
	hover_text_label.text = card.data.text if card.data.text != "" else " "
	hover_popup.visible = true


func _on_card_unhovered(_card: Card) -> void:
	hover_popup.visible = false




# ─────────────────────────────────────────────
#  NAVIGATION
# ─────────────────────────────────────────────

func _on_back_button_pressed() -> void:
	var err = get_tree().change_scene_to_file("res://scenes/menu.tscn")
	if err != OK:
		push_error("Failed to change to Menu scene: %s" % err)
