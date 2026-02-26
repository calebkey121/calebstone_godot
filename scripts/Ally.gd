extends Node2D

class_name Ally

var data: Dictionary = {}
var army_index: int = -1
var is_player_ally: bool = true
var is_selected: bool = false
var is_targetable: bool = false

signal ally_clicked(ally)

func setup(army_data: Dictionary, index: int, is_player: bool) -> void:
	data = army_data
	army_index = index
	is_player_ally = is_player
	_update_ui()

func _update_ui() -> void:
	$name_label.text = data.get("name", "")
	$attack_label.text = str(data.get("attack", 0))
	$health_label.text = str(data.get("health", 0))
	_update_highlight()

func set_selected(val: bool) -> void:
	is_selected = val
	_update_highlight()

func set_targetable(val: bool) -> void:
	is_targetable = val
	_update_highlight()

func _update_highlight() -> void:
	var border = $border
	if is_selected:
		border.default_color = Color(0.2, 1.0, 0.2, 1.0)  # Green — selected attacker
	elif is_targetable:
		border.default_color = Color(1.0, 0.2, 0.2, 1.0)  # Red — valid attack target
	else:
		border.default_color = Color(1, 1, 1, 0)           # Invisible

func _on_clickable_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("ally_clicked", self)
