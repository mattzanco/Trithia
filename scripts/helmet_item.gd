extends "res://scripts/draggable_item.gd"

signal dropped_on_slot(item)

# World helmet item

func _ready():
	super._ready()
	queue_redraw()
	# Allow equip without adjacency when dragging onto UI
	requires_adjacent = true
	# Center pick rect to match centered draw
	pick_rect_offset = -pick_rect_size / 2.0

func _input(event):
	super._input(event)

func equip_helmet():
	var player = get_player_node()
	if player and player.has_method("set_helmet_equipped"):
		player.set_helmet_equipped(true)
		queue_free()

func _draw():
	var texture = get_helmet_texture()
	if texture:
		draw_texture(texture, -texture.get_size() / 2.0)

func get_item_description() -> String:
	return "Helmet\nProtects your head."

static var _helmet_texture: Texture2D = null

static func get_helmet_texture() -> Texture2D:
	if _helmet_texture == null:
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var metal = Color(0.7, 0.7, 0.75)
		var highlight = Color(0.85, 0.85, 0.9)
		var shadow = Color(0.55, 0.55, 0.6)
		# No outline
		# Dome base
		for y in range(6, 18):
			for x in range(6, 26):
				img.set_pixel(x, y, metal)
		# Highlight
		for y in range(8, 13):
			for x in range(10, 16):
				img.set_pixel(x, y, highlight)
		# Shadow band
		for y in range(18, 20):
			for x in range(6, 26):
				img.set_pixel(x, y, shadow)
		# Rim
		for y in range(20, 24):
			for x in range(4, 28):
				img.set_pixel(x, y, metal)
		# Rim highlight
		for y in range(20, 22):
			for x in range(8, 14):
				img.set_pixel(x, y, highlight)
		_helmet_texture = ImageTexture.create_from_image(img)
	return _helmet_texture

func get_shared_texture() -> Texture2D:
	return get_helmet_texture()

func finish_drop():
	if try_equip_in_ui():
		return
	# If dropped over UI but not a valid slot, revert to previous position
	if is_mouse_over_ui():
		global_position = original_position
		return
	super.finish_drop()

func try_equip_in_ui() -> bool:
	var equip_menu = get_tree().get_root().find_child("EquipmentMenu", true, false)
	if equip_menu == null:
		return false
	if equip_menu.has_method("try_equip_helmet_from_world"):
		return equip_menu.try_equip_helmet_from_world(self)
	return false

func is_mouse_over_ui() -> bool:
	var viewport = get_viewport()
	if viewport == null:
		return false
	var hovered = viewport.gui_get_hovered_control()
	return hovered != null
