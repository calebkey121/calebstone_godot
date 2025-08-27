extends Node2D

class_name Hand

var hand_count: int = 0
var max_hand_size: int = 10
var cards: Array[Card] = []

# We need to know where the deck is relative to the hand's origin
# This could be set during initialization or fetched dynamically
# For now, let's assume it's a local position relative to the Hand node's origin
var deck_local_origin_pos := Vector2(300, 0) # EXAMPLE: Adjust as needed!

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
	#    - Animate the NEW card from deck pos to its final anchor_position
	card.move_card(card.anchor_position, Settings.card_draw_duration)

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
	# Calculate the starting x position based on card count, width, and padding
	var total_width = hand_count * Settings.card_width + max(0, hand_count - 1) * Settings.pad
	var initial_x_position = -total_width / 2.0 + Settings.card_width / 2.0 # Center the hand

	var x = initial_x_position
	for i in range(len(cards)):
		var card = cards[i]
		# Calculate the target local position for this card
		var new_anchor_position = Vector2(x, 0) # Assuming y=0 is the hand baseline
		card.anchor_position = new_anchor_position # Store the target
		card.set_base_z_index(i * 5)
		# Move to the next card's x position
		x += Settings.card_width + Settings.pad
