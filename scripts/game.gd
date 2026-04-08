extends Node2D

@onready var http_request = $HTTPRequest
@onready var player_hand: Hand = $Hand
@onready var player_board = $Board
@onready var enemy_board = $Board2
@onready var player_hero_slot: Node2D = $PlayerHeroSlot
@onready var enemy_hero_slot: Node2D = $EnemyHeroSlot
@onready var end_turn_button: Button = $HUDRoot/TopRightHUD/TopRightVBox/EndTurnButton
@onready var gold_label: Label = $HUDRoot/PlayerResourcesHUD/PlayerResources/GoldLabel
@onready var income_label: Label = $HUDRoot/PlayerResourcesHUD/PlayerResources/IncomeLabel
@onready var deck_label: Label = $HUDRoot/PlayerResourcesHUD/PlayerResources/DeckLabel
@onready var round_label: Label = $HUDRoot/TopRightHUD/TopRightVBox/RoundLabel
@onready var status_label: Label = $HUDRoot/TopRightHUD/TopRightVBox/StatusLabel
@onready var enemy_deck_label: Label = $HUDRoot/EnemyResourcesHUD/EnemyResources/EnemyDeckLabel
@onready var enemy_gold_label: Label = $HUDRoot/EnemyResourcesHUD/EnemyResources/EnemyGoldLabel
@onready var enemy_income_label: Label = $HUDRoot/EnemyResourcesHUD/EnemyResources/EnemyIncomeLabel
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
@export var debug_play_card_flow := false

var debug_action_inflight := false
var debug_pending_action: Dictionary = {}

# Attack selection state
var selected_attacker: Card = null
var player_allies: Array = []  # Player-side combat cards (hero slot + board)
var enemy_allies: Array = []   # Enemy-side combat cards (hero slot + board)

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

	# Keep hover popup visually above cards and fully mouse-transparent.
	hover_popup.z_index = 250
	_set_control_subtree_mouse_filter(hover_popup, Control.MOUSE_FILTER_IGNORE)
	hover_popup.move_to_front()

	# Mark the player's board as a valid card drop zone
	var player_board_area = player_board.get_node_or_null("Area2D")
	if player_board_area:
		player_board_area.add_to_group("card_drop_area")

	# Load initial game state from server
	current_request = RequestType.LOAD_GAME
	NetworkManager.load_game(http_request, GameState.session_id)


func _set_control_subtree_mouse_filter(root: Control, filter_mode: Control.MouseFilter) -> void:
	root.mouse_filter = filter_mode
	for child in root.get_children():
		if child is Control:
			_set_control_subtree_mouse_filter(child, filter_mode)


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

	var player_hero = _hero_to_board_card_data(GameState.current_player.get("hero", {}))
	var enemy_hero = _hero_to_board_card_data(GameState.opposing_player.get("hero", {}))
	var player_army: Array = GameState.current_player.get("army", [])
	var enemy_army: Array = GameState.opposing_player.get("army", [])

	# Hero cards live in side slots but stay in ally arrays for selection/targeting.
	if not player_hero.is_empty():
		var player_hero_card: Card = _spawn_board_card(player_hero, 0, true)
		player_hero_slot.add_child(player_hero_card)
		player_allies.append(player_hero_card)
		player_hero_card.position = Vector2.ZERO
		player_hero_card.anchor_position = Vector2.ZERO

	if not enemy_hero.is_empty():
		var enemy_hero_card: Card = _spawn_board_card(enemy_hero, 0, false)
		enemy_hero_slot.add_child(enemy_hero_card)
		enemy_allies.append(enemy_hero_card)
		enemy_hero_card.position = Vector2.ZERO
		enemy_hero_card.anchor_position = Vector2.ZERO

	for i in range(player_army.size()):
		var card: Card = _spawn_board_card(player_army[i], i + 1, true)
		player_board.add_child(card)
		player_allies.append(card)
		card.position = Vector2((i - player_army.size() / 2.0 + 0.5) * 130, 0)
		card.anchor_position = card.position

	for i in range(enemy_army.size()):
		var card: Card = _spawn_board_card(enemy_army[i], i + 1, false)
		enemy_board.add_child(card)
		enemy_allies.append(card)
		card.position = Vector2((i - enemy_army.size() / 2.0 + 0.5) * 130, 0)
		card.anchor_position = card.position


func _hero_to_board_card_data(hero: Dictionary) -> Dictionary:
	if hero.is_empty():
		return {}
	var hero_art_id := str(hero.get("hero_id", ""))
	if hero_art_id == "":
		hero_art_id = str(hero.get("card_id", ""))
	if hero_art_id == "":
		hero_art_id = str(hero.get("name", "hero")).to_lower()
		hero_art_id = hero_art_id.replace("'", "").replace("-", "_").replace(" ", "_")
	return {
		"instance_id": hero.get("instance_id", ""),
		"card_id": hero_art_id,
		"name": hero.get("name", "Hero"),
		"cost": hero.get("cost", 0),
		"health": hero.get("health", 0),
		"attack": hero.get("attack", 0),
		"text": hero.get("text", ""),
		"can_attack": hero.get("can_attack", false),
		"type": "card",
		"zone": "hero",
		"tags": hero.get("tags", [])
	}


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
	deck_label.text = "Deck: %d" % cp.get("deck_count", 0)

	enemy_gold_label.text = "Gold: %d" % op.get("gold", 0)
	enemy_income_label.text = "Income: %d" % op.get("income", 0)
	enemy_deck_label.text = "Deck: %d" % op.get("deck_count", 0)

	if waiting_for_server:
		status_label.text = "Waiting..."
		status_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 1))
	elif GameState.is_game_over:
		status_label.text = "Game Over"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1))
	elif GameState.active_player_id != "" and GameState.active_player_id != GameState.local_player_id:
		status_label.text = "Opponent Turn"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 1))
	else:
		status_label.text = "Your Turn"
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1))
	var opponent_turn := GameState.active_player_id != "" and GameState.active_player_id != GameState.local_player_id
	end_turn_button.disabled = waiting_for_server or GameState.is_game_over or opponent_turn


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
	if not _is_play_card_legal(instance_id):
		if status_label:
			status_label.text = "Illegal move"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1))
		return

	var action := {"type": "play_card", "card_instance_id": instance_id}

	if debug_play_card_flow and not debug_action_inflight:
		debug_action_inflight = true
		debug_pending_action = action
		waiting_for_server = true
		end_turn_button.disabled = true
		status_label.text = "Waiting..."
		current_request = RequestType.DEBUG_PRE_ACTION
		NetworkManager.load_game(http_request, GameState.session_id)
		return

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


func _is_play_card_legal(card_instance_id: String) -> bool:
	for action in GameState.legal_actions:
		if not (action is Dictionary):
			continue
		if action.get("type", "") != "play_card":
			continue
		if action.get("card_instance_id", "") == card_instance_id:
			return true
	return false


# ─────────────────────────────────────────────
#  HTTP RESPONSE
# ─────────────────────────────────────────────

func _on_http_request_completed(_result, response_code, _headers, body) -> void:
	if api_debug:
		print("API response code -> ", response_code)
		print("API response body -> ", body.get_string_from_utf8())
	if response_code == 422:
		waiting_for_server = false
		if status_label:
			status_label.text = "Illegal move"
			status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1))
		end_turn_button.disabled = false
		current_request = RequestType.LOAD_GAME
		NetworkManager.load_game(http_request, GameState.session_id)
		return
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
			setup(response)
		RequestType.DEBUG_PRE_ACTION:
			print("gamestate_before:\n", body.get_string_from_utf8())
			current_request = RequestType.SUBMIT_ACTION
			NetworkManager.submit_action(http_request, GameState.session_id, debug_pending_action)
		RequestType.SUBMIT_ACTION:
			# Action responses: { "status": "success", "game_state": {...} }
			if debug_action_inflight:
				print("playing card:\n", JSON.stringify(debug_pending_action))
				print("action_response:\n", body.get_string_from_utf8())
			setup(response)
			if debug_action_inflight:
				current_request = RequestType.DEBUG_POST_ACTION
				NetworkManager.load_game(http_request, GameState.session_id)
		RequestType.DEBUG_POST_ACTION:
			print("gamestate_after:\n", body.get_string_from_utf8())
			debug_action_inflight = false
			debug_pending_action = {}


# ─────────────────────────────────────────────
#  GAME OVER
# ─────────────────────────────────────────────

func _show_game_over() -> void:
	var local_hero = GameState.current_player.get("hero", {})
	var enemy_hero = GameState.opposing_player.get("hero", {})
	var local_hp: int = local_hero.get("health", 0)
	var enemy_hp: int = enemy_hero.get("health", 0)

	var local_result_key := "%s_win" % GameState.local_player_id
	if GameState.result == local_result_key:
		game_over_sub_label.text = "You Win!"
	elif GameState.result == "tie":
		game_over_sub_label.text = "Draw"
	elif GameState.result != "in_progress":
		game_over_sub_label.text = "You Lose!"
	elif local_hp > 0 and enemy_hp <= 0:
		game_over_sub_label.text = "You Win!"
	elif local_hp <= 0 and enemy_hp > 0:
		game_over_sub_label.text = "You Lose!"
	elif local_hp <= 0 and enemy_hp <= 0:
		game_over_sub_label.text = "Draw"
	else:
		game_over_sub_label.text = "Game Over"
	hover_popup.visible = false
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
	hover_popup.move_to_front()
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
