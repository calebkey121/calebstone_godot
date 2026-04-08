extends Node

var textures = {}

func _ready():
	preload_textures()

func preload_textures():
	textures["card_frame"] = preload("res://assets/card_frames/card_frame.png")
	textures["card_frame_1"] = preload("res://assets/card_frames/card_frame_1.png")
	textures["card_frame_5"] = preload("res://assets/card_frames/card_frame_5.png")
	textures["card_frame_10"] = preload("res://assets/card_frames/card_frame_10.png")
	textures["card_frame_11"] = preload("res://assets/card_frames/card_frame_11.png")
	textures["card_frame_12"] = preload("res://assets/card_frames/card_frame_12.png")
	textures["card_frame_cf1"] = preload("res://assets/card_frames/cf1.png")

	# Global art fallback when dynamic lookup misses.
	textures["default_card_art"] = preload("res://assets/card_art/mercenary_captain.png")


func get_texture(tex_name):
	if textures.has(tex_name):
		return textures[tex_name]

	var key := str(tex_name)

	# Frame keys are static.
	if key.begins_with("card_frame"):
		push_warning("Frame not found: %s" % key)
		return textures.get("card_frame_cf1", null)

	# Card art keys are dynamic. Prefer API card_id (snake_case), then normalize
	# legacy display-name/PascalCase keys to snake_case.
	var dynamic_texture = _load_dynamic_art_texture(key)
	if dynamic_texture != null:
		textures[key] = dynamic_texture
		return dynamic_texture

	push_warning("Texture not found: %s" % key)
	return textures.get("default_card_art", null)


func _load_dynamic_art_texture(key: String):
	var candidates: Array[String] = []

	# If caller already passed a direct asset-like key, try it first.
	candidates.append(key)

	# Legacy/display name and PascalCase normalization to snake_case.
	candidates.append(_to_snake_asset_key(key))

	for base in candidates:
		var cleaned = base.strip_edges()
		if cleaned == "":
			continue
		var png_path = "res://assets/card_art/%s.png" % cleaned
		if ResourceLoader.exists(png_path):
			return load(png_path)
		var webp_path = "res://assets/card_art/%s.webp" % cleaned
		if ResourceLoader.exists(webp_path):
			return load(webp_path)
	return null


func _to_snake_asset_key(value: String) -> String:
	var normalized = value.strip_edges().replace("'", "").replace("-", " ").replace("_", " ")
	var tokens = normalized.split(" ", false)
	var out := ""
	for token in tokens:
		if token == "":
			continue
		var token_out := ""
		for i in range(token.length()):
			var ch = token.substr(i, 1)
			var is_upper = ch == ch.to_upper() and ch != ch.to_lower()
			if is_upper and i > 0:
				var prev = token.substr(i - 1, 1)
				var prev_is_alpha = prev == prev.to_lower() and prev != prev.to_upper()
				var prev_is_digit = prev >= "0" and prev <= "9"
				if prev_is_alpha or prev_is_digit:
					token_out += "_"
			token_out += ch.to_lower()
		if out != "":
			out += "_"
		out += token_out
	return out
