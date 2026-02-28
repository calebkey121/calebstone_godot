extends Node2D

class_name Hand

var hand_count: int = 0
var max_hand_size: int = 10
var cards: Array[Card] = []

# Where new cards animate from (local to the Hand node)
@export var deck_local_origin_pos := Vector2(300, 0)

func add_card(data: CardData):
	if hand_count >= max_hand_size:
		return false # Hand is full

	var card = CardManager.create_card(data)
	if card == null:
		push_error("Failed to create card instance for: %s" % data.name)
		return false

	# 1. Set initial position (visually near the deck, but local to Hand node)
	card.position = deck_local_origin_pos

	# 2. Add card node to the scene tree (as child of Hand)
	add_child(card)

	# 3. Add card reference to our internal array
	cards.append(card)
	hand_count += 1

	# 4. Recalculate target positions for ALL cards (updates anchor_position)
	update_card_positions()

	# 5. Trigger animations:
	#    - NEW card: deck -> its anchor (draw animation)
	#    - EXISTING cards: nudge to their new anchors (reorganize animation, short)
	for c in cards:
		if c == card:
			c.move_card(c.anchor_position, Settings.card_draw_duration)
		else:
			if c.position != c.anchor_position:
				c.move_card(c.anchor_position, Settings.card_reorganize_duration)

	return true

# create from a list of actual cards, or the json object
func add_cards(data_array: Array):
	var success = true
	for data in data_array:
		if not data is CardData:
			push_warning("Invalid data type passed to add_cards.")
			continue # Skip non-CardData items

		if not add_card(data):
			# Stop adding if hand gets full or an error occurs
			success = false
			# Potentially return the cards that couldn't be added
			break
	return success


# Removes the card at the given index
func remove_card(index: int):
	if index < 0 or index >= hand_count:
		push_error("Invalid index to remove card: %d" % index)
		return false

	# 1. Get reference to the card node
	var card_to_remove = cards[index]

	# 2. Remove from internal array
	cards.pop_at(index)
	hand_count -= 1

	# 3. Recalculate target positions for REMAINING cards
	update_card_positions()

	# 4. Trigger animations for REMAINING cards to move to their new positions
	for card in cards:
		# Optional check: only move if position actually changed
		if card.position != card.anchor_position:
			card.move_card(card.anchor_position, Settings.card_reorganize_duration)

	# 5. Remove the actual card node from the scene tree
	#    (Consider a discard animation tween before this if desired)
	card_to_remove.queue_free()

	return true


func remove_all_cards():
	# Iterate backwards when removing multiple items to avoid index issues
	for i in range(hand_count - 1, -1, -1):
		remove_card(i)


# Calculates and sets the target LOCAL anchor_position for each card
# Does NOT trigger movement itself.
func update_card_positions():
	# Calculate effective padding so the hand clamps to a max width and can overlap
	var viewport_width: float = get_viewport_rect().size.x
	var max_width: float = min(float(Settings.hand_max_width), viewport_width - float(Settings.hand_margin) * 2.0)
	max_width = max(max_width, float(Settings.card_width))

	var effective_pad: float = Settings.pad
	if hand_count > 1:
		var raw_pad = (max_width - hand_count * Settings.card_width) / float(hand_count - 1)
		effective_pad = clamp(raw_pad, float(Settings.hand_min_pad), float(Settings.pad))

	# Calculate the starting x position based on card count, width, and effective padding
	var total_width = hand_count * Settings.card_width + max(0, hand_count - 1) * effective_pad
	var initial_x_position = -total_width / 2.0 + Settings.card_width / 2.0 # Center the hand

	var x = initial_x_position
	for i in range(len(cards)):
		var card = cards[i]
		# Calculate the target local position for this card
		var new_anchor_position = Vector2(x, 0) # Assuming y=0 is the hand baseline
		card.anchor_position = new_anchor_position # Store the target
		card.set_base_z_index(i * 5)
		# Move to the next card's x position
		x += Settings.card_width + effective_pad


func rebuild_from_card_data(data_array: Array) -> void:
	remove_all_cards()
	for data in data_array:
		if data is CardData:
			add_card(data)
		elif data is Dictionary:
			add_card(CardData.new(data))


func sync_from_card_data(data_array: Array) -> void:
	var new_data: Array[CardData] = []
	for data in data_array:
		if data is CardData:
			new_data.append(data)
		elif data is Dictionary:
			new_data.append(CardData.new(data))

	var old_count := cards.size()
	var new_count := new_data.size()

	# Trim extra cards without triggering deck animations.
	while cards.size() > new_count:
		var extra = cards.pop_back()
		hand_count -= 1
		extra.queue_free()

	# Update existing cards in place.
	for i in range(min(old_count, new_count)):
		cards[i].set_data(new_data[i])

	# Add new cards at the end (these will animate from deck_local_origin_pos).
	for i in range(old_count, new_count):
		var card = CardManager.create_card(new_data[i])
		if card == null:
			push_error("Failed to create card instance for: %s" % new_data[i].name)
			continue
		card.position = deck_local_origin_pos
		add_child(card)
		cards.append(card)
		hand_count += 1

	# Recalculate anchors and animate.
	update_card_positions()
	for i in range(cards.size()):
		var card = cards[i]
		if i >= old_count:
			card.move_card(card.anchor_position, Settings.card_draw_duration)
		elif card.position != card.anchor_position:
			card.move_card(card.anchor_position, Settings.card_reorganize_duration)
