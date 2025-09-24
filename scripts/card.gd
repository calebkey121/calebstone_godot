extends Node2D

class_name Card

var data: CardData

func set_data(new_data: CardData):
	data = new_data
	update_data_ui()

# UI
func update_data_ui():
	$card_name_label.text = data.name
	#$HealthLabel.text = str(data.health)
	#$AttackLabel.text = str(data.attack)
	#$CostLabel.text = str(data.cost)
	
# Variables to store the original scale and timer state
var base_z_index: float
var anchor_position := Vector2()
var hovering: bool = false
var expanded: bool = false

@onready var clickable_area = $card_area

func _ready():
	anchor_position = self.global_position
	clickable_area.gui_input.connect(_on_clickable_area_input_event)

func _process(_delta):
	pass

func move_card(new_position, duration: float = 0.15):
	if new_position == null:
		new_position = anchor_position
	
	var tween = create_tween()
	tween.tween_property(self, "position", new_position, duration) \
		.set_trans(Tween.TRANS_LINEAR) \
		.set_ease(Tween.EASE_IN_OUT)

func set_base_z_index(index: int):
	self.base_z_index = index
	# Apply immediately ONLY IF NOT currently hovering/being dragged
	# CardManager handles Z during drag via CanvasLayer
	if not hovering and not CardManager.is_card_dragging(self):
		self.z_index = index

func _on_clickable_area_input_event(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			CardManager.start_drag(self)
		elif CardManager.is_card_dragging(self):
			CardManager.end_drag()

func _is_mouse_hovering() -> bool:
	return clickable_area.get_global_rect().has_point(get_global_mouse_position())
