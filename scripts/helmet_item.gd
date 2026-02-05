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
	return "Cloth Hat\nSimple headwear."

static var _helmet_texture: Texture2D = null

static func get_helmet_texture() -> Texture2D:
	if _helmet_texture == null:
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var cloth = Color(0.65, 0.6, 0.5)
		var dark = Color(0.5, 0.45, 0.38)
		var highlight = Color(0.75, 0.7, 0.6)
		# Cap top (shifted down to visually center in 32x32 tile)
		for y in range(10, 18):
			for x in range(8, 24):
				img.set_pixel(x, y, cloth)
		# Brim
		for y in range(18, 20):
			for x in range(6, 26):
				img.set_pixel(x, y, dark)
		# Highlight
		for y in range(11, 14):
			for x in range(12, 16):
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
