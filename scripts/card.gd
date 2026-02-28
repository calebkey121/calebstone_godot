extends Node2D

class_name Card

var data: CardData
signal card_clicked(card)

@export var allow_drag := true
@export var allow_click := false
@export var board_mode := false

var army_index: int = -1
var is_player_ally: bool = true
var is_selected: bool = false
var is_targetable: bool = false
var can_attack: bool = false
@export var face_down := false : set = set_face_down
@export var card_back_offset := Vector2(-3.0, 0.0)
@export var card_back_scale := Vector2(0.3, 0.3)

func set_data(new_data: CardData):
	data = new_data
	update_data_ui()

# UI
func update_data_ui():
	var name_label = get_node_or_null("StatsRoot/name_label")
	if name_label:
		_update_name_label(name_label, data.name)
	var health_label = get_node_or_null("StatsRoot/health_label")
	if health_label:
		health_label.text = str(data.health)
	var attack_label = get_node_or_null("StatsRoot/attack_label")
	if attack_label:
		attack_label.text = str(data.attack)
	var cost_label = get_node_or_null("StatsRoot/cost_label")
	if cost_label:
		cost_label.text = str(data.cost)
	
# Variables to store the original scale and timer state
var base_z_index: float
var anchor_position := Vector2()
var hovering: bool = false
var expanded: bool = false
var move_tween: Tween = null
var hover_tween: Tween = null
var base_scale: Vector2

@export var name_font_size_max := 22
@export var name_font_size_min := 8
@export var name_shrink_start := 8
@export var name_shrink_per_char := 1.2

@onready var clickable_area = $card_area
@onready var stats_root: Node2D = get_node_or_null("StatsRoot")
@onready var card_frame: Sprite2D = get_node_or_null("card_frame")
@onready var card_art: Sprite2D = get_node_or_null("card_art")
@onready var card_back: Sprite2D = get_node_or_null("card_back")


func _ready():
	# anchor_position is set by Hand.update_card_positions(), not from global_position
	anchor_position = self.position
	clickable_area.gui_input.connect(_on_clickable_area_input_event)
	clickable_area.mouse_entered.connect(_on_card_area_mouse_entered)
	clickable_area.mouse_exited.connect(_on_card_area_mouse_exited)
	base_scale = scale
	if stats_root:
		stats_root.z_as_relative = true
		_flatten_stats_z()
	_update_highlight()
	_apply_face_state()

func _process(_delta):
	pass

func move_card(new_position, duration: float = 0.15):
	if new_position == null:
		new_position = anchor_position

	# Kill any previous movement tween so tweens don't fight over "position"
	if move_tween != null and move_tween.is_running():
		move_tween.kill()

	move_tween = create_tween()
	move_tween.tween_property(self, "position", new_position, duration) \
		.set_trans(Tween.TRANS_LINEAR) \
		.set_ease(Tween.EASE_IN_OUT)

func set_base_z_index(index: int):
	self.base_z_index = index
	# Apply immediately ONLY IF NOT currently hovering/being dragged
	# CardManager handles Z during drag via CanvasLayer
	if not hovering and not CardManager.is_card_dragging(self):
		self.z_index = index
		_sync_stats_z()

func _on_clickable_area_input_event(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if allow_click:
				emit_signal("card_clicked", self)
			if allow_drag:
				if hovering:
					_set_hovered(false)
				CardManager.start_drag(self)
		elif allow_drag and CardManager.is_card_dragging(self):
			CardManager.end_drag()

func _is_mouse_hovering() -> bool:
	return clickable_area.get_global_rect().has_point(get_global_mouse_position())


func _on_card_area_focus_entered() -> void:
	_set_hovered(true)


func _on_card_area_focus_exited() -> void:
	_set_hovered(false)


func _on_card_area_mouse_entered() -> void:
	_set_hovered(true)


func _on_card_area_mouse_exited() -> void:
	_set_hovered(false)


func _set_hovered(is_hovered: bool) -> void:
	if is_hovered:
		if hovering or CardManager.is_any_card_dragging() or CardManager.other_card_expanded(self):
			return
		hovering = true
		expanded = true
		CardManager.expand_card(self)
		CardManager.emit_signal("card_hovered", self)
		_start_hover_tween(base_scale * Settings.card_hover_scale, Settings.card_hover_duration)
		self.z_index = base_z_index + 50
		_sync_stats_z()
	else:
		if not hovering:
			return
		hovering = false
		expanded = false
		CardManager.shink_card(self)
		CardManager.emit_signal("card_unhovered", self)
		if not CardManager.is_card_dragging(self):
			self.z_index = base_z_index
			_sync_stats_z()
		_start_hover_tween(base_scale, Settings.card_hover_duration)


func _start_hover_tween(target_scale: Vector2, duration: float) -> void:
	if hover_tween != null and hover_tween.is_running():
		hover_tween.kill()
	hover_tween = create_tween()
	hover_tween.tween_property(self, "scale", target_scale, duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)


func _sync_stats_z() -> void:
	if stats_root:
		# Keep stats on the same layer as the card so they don't bleed over neighbors.
		stats_root.z_index = 0


func _flatten_stats_z() -> void:
	if not stats_root:
		return
	stats_root.z_index = 0
	for child in stats_root.get_children():
		if child is CanvasItem:
			child.z_as_relative = true
			child.z_index = 0


func setup_board(ally_data: Dictionary, index: int, is_player: bool) -> void:
	board_mode = true
	allow_click = true
	allow_drag = true
	army_index = index
	is_player_ally = is_player
	can_attack = ally_data.get("can_attack", false)
	_update_highlight()


func set_selected(val: bool) -> void:
	is_selected = val
	_update_highlight()


func set_targetable(val: bool) -> void:
	is_targetable = val
	_update_highlight()


func _update_highlight() -> void:
	if not board_mode:
		return
	var border = get_node_or_null("border")
	if not border:
		return
	if is_selected:
		border.default_color = Color(0.2, 1.0, 0.2, 1.0)
	elif is_targetable:
		border.default_color = Color(1.0, 0.2, 0.2, 1.0)
	else:
		border.default_color = Color(1, 1, 1, 0)


func set_face_down(value: bool) -> void:
	face_down = value
	_apply_face_state()


func _apply_face_state() -> void:
	if card_frame:
		card_frame.visible = not face_down
	if card_art:
		card_art.visible = not face_down
	if stats_root:
		stats_root.visible = not face_down
	if card_back:
		card_back.visible = face_down
		card_back.position = card_back_offset
		card_back.scale = card_back_scale


func _name_font_size_for(text: String) -> int:
	var extra = max(0, text.length() - name_shrink_start)
	var size := float(name_font_size_max) - float(extra) * name_shrink_per_char
	return int(clamp(size, float(name_font_size_min), float(name_font_size_max)))


func _update_name_label(name_label: Control, text: String) -> void:
	name_label.text = text
	var size := _name_font_size_for(text)
	if name_label is RichTextLabel:
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.fit_content = true
		name_label.add_theme_font_size_override("normal_font_size", size)
		name_label.add_theme_font_size_override("bold_font_size", size)
		name_label.add_theme_font_size_override("italics_font_size", size)
		name_label.add_theme_font_size_override("bold_italics_font_size", size)
	elif name_label is Label:
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.clip_text = false
		name_label.add_theme_font_size_override("font_size", size)
	else:
		name_label.add_theme_font_size_override("font_size", size)
