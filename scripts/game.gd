extends Node2D

var game_data = {}

# Preload Scenes
var HeroScene: PackedScene = preload("res://scenes/hero.tscn")

@onready var http_request = $HTTPRequest
@onready var player1_hand = $Hand
@onready var player2_hand = $Hand2

func _ready():
	# Connect HTTPRequest signals
	http_request.request_completed.connect(_on_http_request_completed)
	NetworkManager.load_game($HTTPRequest, GameState.session_id)

func setup(data):
	game_data = data
	print("Game scene initialized with data:", game_data)
	
	# Dummy Data for the Hero Cards
	var hero_data_dict: Dictionary = {
		"name": "", # will be filled in
		"attack": 0,
		"health": 100,
		"cost": -1,
		"text": "player1"
	}
	var hero_data: CardData = CardData.new(hero_data_dict)
	hero_data.name = game_data["current_player"]["hero"]["name"]
	var player1_hero: Card = CardManager.create_hero(hero_data)
	hero_data.name = game_data["opposing_player"]["hero"]["name"]
	hero_data.text = "player2"
	var player2_hero: Card = CardManager.create_hero(hero_data)
	
	add_child(player1_hero)
	add_child(player2_hero)
	for d in game_data["current_player"]["hand"]:
		player1_hand.add_card(CardData.new(d))
	for d in game_data["opposing_player"]["hand"]:
		player2_hand.add_card(CardData.new(d))
	var hero1_pos := Vector2(0, 0)
	var hero2_pos := Vector2(-500, -200)
	player1_hero.get_child(0).offset = hero1_pos
	player2_hero.get_child(0).offset = hero2_pos

# Callback for when the HTTP request completes, load game
func _on_http_request_completed(_result, response_code, _headers, body):
	if response_code == 200:  # HTTP OK
		var response = JSON.parse_string(body.get_string_from_utf8())
		# Emit the signal with game data
		setup(response)

func _on_back_button_pressed():
	var err = get_tree().change_scene_to_file("res://scenes/menu.tscn")
	if err != OK:
		push_error("Failed to change to Menu scene: %s" % err)
