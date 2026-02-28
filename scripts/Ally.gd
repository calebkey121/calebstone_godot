@tool
extends Node2D

class_name Ally

var data: Dictionary = {}
var army_index: int = -1
var is_player_ally: bool = true
var is_selected: bool = false
var is_targetable: bool = false

signal ally_clicked(ally)

@export var editor_preview_enabled: bool = true
@export var editor_frame_texture: Texture2D : set = _set_editor_frame_texture
@export var editor_art_texture: Texture2D : set = _set_editor_art_texture

@onready var card_visual: Node2D = $CardVisual
@onready var cost_label: Label = $cost_label
@onready var editor_frame: Sprite2D = $CardVisual/card_frame
@onready var editor_art: Sprite2D = $CardVisual/card_art

func setup(army_data: Dictionary, index: int, is_player: bool) -> void:
	data = army_data
	army_index = index
	is_player_ally = is_player
	if not is_inside_tree():
		call_deferred("_update_ui")
		return
	_update_ui()

func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_editor_preview()

func _update_ui() -> void:
	$name_label.text = data.get("name", "")
	$attack_label.text = str(data.get("attack", 0))
	$health_label.text = str(data.get("health", 0))
	_update_cost()
	_apply_visuals()
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


func _update_cost() -> void:
	cost_label.text = str(data.get("cost", 0))


func _apply_visuals() -> void:
	if Engine.is_editor_hint() and editor_preview_enabled:
		return
	var card_name: String = data.get("name", "")
	if card_name == "":
		return

	var visual = card_visual if card_visual else get_node_or_null("CardVisual")
	if visual == null:
		call_deferred("_apply_visuals")
		return

	var frames_data = Tools.load_data_from_json("res://card_data/card_frames.json")
	if frames_data == null or not frames_data.has(Settings.card_frame):
		return

	var frame_data = frames_data[Settings.card_frame]

	var frame_adjustment = frame_data["frame_adjustment"]
	var frame_position = Vector2(frame_adjustment["position"]["x"], frame_adjustment["position"]["y"])
	var frame_scale = Vector2(frame_adjustment["scale"]["x"], frame_adjustment["scale"]["y"])

	var art_adjustment = frame_data["art_adjustment"]
	var art_region_rect: Rect2
	var art_position: Vector2
	var art_scale: Vector2

	if card_name in art_adjustment:
		var card_adjust = art_adjustment[card_name]
		art_region_rect = Rect2(
			Vector2(card_adjust["region_rect"]["x"], card_adjust["region_rect"]["y"]),
			Vector2(card_adjust["region_rect"]["width"], card_adjust["region_rect"]["height"])
		)
		art_position = Vector2(card_adjust["position"]["x"], card_adjust["position"]["y"])
		art_scale = Vector2(card_adjust["scale"]["x"], card_adjust["scale"]["y"])
	else:
		var default = art_adjustment["default"]
		art_region_rect = Rect2(
			Vector2(default["region_rect"]["x"], default["region_rect"]["y"]),
			Vector2(default["region_rect"]["width"], default["region_rect"]["height"])
		)
		art_position = Vector2(default["position"]["x"], default["position"]["y"])
		art_scale = Vector2(default["scale"]["x"], default["scale"]["y"])

	CardManager.set_frame_texture(visual, Settings.card_frame, frame_position, frame_scale)
	CardManager.set_card_texture(visual, card_name, art_region_rect, art_position, art_scale)


func _set_editor_frame_texture(value: Texture2D) -> void:
	editor_frame_texture = value
	if Engine.is_editor_hint():
		_apply_editor_preview()


func _set_editor_art_texture(value: Texture2D) -> void:
	editor_art_texture = value
	if Engine.is_editor_hint():
		_apply_editor_preview()


func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint() or not editor_preview_enabled:
		return
	if not is_inside_tree():
		call_deferred("_apply_editor_preview")
		return
	if editor_frame and editor_frame_texture:
		editor_frame.texture = editor_frame_texture
	if editor_art and editor_art_texture:
		editor_art.texture = editor_art_texture
		editor_art.region_enabled = false
