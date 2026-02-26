extends Node2D

# Preloaded scenes
var AllyScene: PackedScene = preload("res://scenes/ally.tscn")
var CardBackTexture: Texture2D = preload("res://assets/card_backs/calebstone_cardback.png")

@onready var http_request = $HTTPRequest
@onready var player_hand: Hand = $Hand
@onready var player_board = $Board
@onready var enemy_board = $Board2
@onready var end_turn_button: Button = $HUD/EndTurnButton
@onready var gold_label: Label = $HUD/GoldLabel
@onready var income_label: Label = $HUD/IncomeLabel
@onready var round_label: Label = $HUD/RoundLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var p1_hero_label: Label = $HUD/P1HeroLabel
@onready var p2_hero_label: Label = $HUD/P2HeroLabel
@onready var opponent_hand_container: Node2D = $Hand2

# Attack selection state
var selected_attacker: Ally = null
var player_allies: Array = []  # Ally nodes on player board
var enemy_allies: Array = []   # Ally nodes on enemy board

# Prevent double-input while a request is in-flight
var waiting_for_server: bool = false

# Which HTTP response are we expecting
enum RequestType { LOAD_GAME, SUBMIT_ACTION }
var current_request: RequestType = RequestType.LOAD_GAME


func _ready() -> void:
	http_request.request_completed.connect(_on_http_request_completed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	CardManager.card_drag_ended.connect(_on_card_drag_ended)

	# Mark the player's board as a valid card drop zone
	player_board.add_to_group("card_drop_area")

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
	player_hand.remove_all_cards()
	for card_dict in GameState.current_player.get("hand", []):
		player_hand.add_card(CardData.new(card_dict))


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
		var ally: Ally = _spawn_ally(player_army[i], i, true)
		player_board.add_child(ally)
		player_allies.append(ally)
		ally.position = Vector2((i - player_army.size() / 2.0 + 0.5) * 130, 0)

	for i in range(enemy_army.size()):
		var ally: Ally = _spawn_ally(enemy_army[i], i, false)
		enemy_board.add_child(ally)
		enemy_allies.append(ally)
		ally.position = Vector2((i - enemy_army.size() / 2.0 + 0.5) * 130, 0)


func _spawn_ally(ally_data: Dictionary, index: int, is_player: bool) -> Ally:
	var ally: Ally = AllyScene.instantiate()
	ally.setup(ally_data, index, is_player)
	ally.ally_clicked.connect(_on_ally_clicked)
	return ally


func _rebuild_opponent_hand() -> void:
	for child in opponent_hand_container.get_children():
		child.queue_free()

	var hand_count: int = GameState.opposing_player.get("hand", []).size()
	for i in range(hand_count):
		var card_back = Sprite2D.new()
		card_back.texture = CardBackTexture
		card_back.scale = Vector2(0.1, 0.1)
		card_back.position = Vector2((i - hand_count / 2.0 + 0.5) * 70, 0)
		opponent_hand_container.add_child(card_back)


func _update_hud() -> void:
	var cp = GameState.current_player
	var op = GameState.opposing_player

	gold_label.text = "Gold: %d" % cp.get("gold", 0)
	income_label.text = "Income: %d" % cp.get("income", 0)
	round_label.text = "Round: %d" % GameState.current_round

	var p1_hero = cp.get("hero", {})
	var p2_hero = op.get("hero", {})
	p1_hero_label.text = "%s  HP: %d" % [p1_hero.get("name", "Hero"), p1_hero.get("health", 0)]
	p2_hero_label.text = "%s  HP: %d" % [p2_hero.get("name", "Hero"), p2_hero.get("health", 0)]

	status_label.text = "Waiting..." if waiting_for_server else "Your Turn"
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

	# Remove card from hand visually; board will fully rebuild on server response
	player_hand.remove_card(idx)
	_submit_action({"type": "play_card", "card_index": idx})


func _on_ally_clicked(ally: Ally) -> void:
	if waiting_for_server:
		return

	if ally.is_player_ally:
		# Selecting / deselecting a friendly attacker
		if selected_attacker == ally:
			ally.set_selected(false)
			selected_attacker = null
			_clear_target_highlights()
		elif ally.data.get("can_attack", false):
			if selected_attacker:
				selected_attacker.set_selected(false)
			selected_attacker = ally
			ally.set_selected(true)
			_highlight_targets()
	else:
		# Clicking an enemy: perform attack if we have a selected attacker
		if selected_attacker != null:
			var attacker_idx = selected_attacker.army_index
			var target_idx = ally.army_index
			selected_attacker.set_selected(false)
			selected_attacker = null
			_clear_target_highlights()
			_submit_action({
				"type": "attack",
				"attacker_index": attacker_idx,
				"target_index": target_idx
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
	waiting_for_server = true
	end_turn_button.disabled = true
	status_label.text = "Waiting..."
	current_request = RequestType.SUBMIT_ACTION
	NetworkManager.submit_action(http_request, GameState.session_id, action)


# ─────────────────────────────────────────────
#  HTTP RESPONSE
# ─────────────────────────────────────────────

func _on_http_request_completed(_result, response_code, _headers, body) -> void:
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
		RequestType.SUBMIT_ACTION:
			# Action responses: { "status": "success", "game_state": {...} }
			var game_state = response.get("game_state", response)
			setup(game_state)


# ─────────────────────────────────────────────
#  GAME OVER
# ─────────────────────────────────────────────

func _show_game_over() -> void:
	status_label.text = "Game Over!"
	end_turn_button.disabled = true


# ─────────────────────────────────────────────
#  NAVIGATION
# ─────────────────────────────────────────────

func _on_back_button_pressed() -> void:
	var err = get_tree().change_scene_to_file("res://scenes/menu.tscn")
	if err != OK:
		push_error("Failed to change to Menu scene: %s" % err)
