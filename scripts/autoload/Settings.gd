extends Node

# Information
var frames: Array = []
var cards: Array = []

# Settings
var pad: int = 15
var card_width: int = 105
var card_frame: String = "card_frame_cf1"
var hero_frame: String = "card_frame_10"
var hand_max_width: int = 500
var hand_margin: int = 120
var hand_min_pad: int = -1000
var card_hover_scale: float = 1.15
var card_hover_duration: float = 0.12

# How quickly the card catches up to the mouse cursor during drag (higher = faster)
# Good values are often between 5.0 and 15.0
var card_follow_speed: float = 10.0

# Duration (in seconds) for the tween when a card returns to hand/original spot
var card_return_duration: float = 0.2

# Duration (in seconds) for the tween when a card moves to a drop zone
var card_drop_duration: float = 0.15

# Duration (in seconds) for the tween when drawing a card (deck to hand)
var card_draw_duration: float = 0.4

# Duration (in seconds) for the tween when cards shift position within the hand
var card_reorganize_duration: float = 0.2

# Called when the node enters the scene tree for the first time.
func _ready():
	categorize_textures(TextureManager.textures)

func set_card_frame(frame: String) -> void:
	card_frame = frame

func set_hero_frame(frame: String) -> void:
	hero_frame = frame

func categorize_textures(textures: Dictionary):
	# Loop through the dictionary keys
	for key in textures.keys():
		if key.begins_with("card_frame"):
			frames.append(key)
		else:
			cards.append(key)
