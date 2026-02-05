extends "res://scripts/draggable_item.gd"

signal dropped_on_slot(item)

# World cloth boots item

func _ready():
	super._ready()
	queue_redraw()
	requires_adjacent = true
	pick_rect_offset = -pick_rect_size / 2.0

func _input(event):
	super._input(event)

func _draw():
	var texture = get_boots_texture()
	if texture:
		draw_texture(texture, -texture.get_size() / 2.0)

func get_item_description() -> String:
	return "Cloth Boots\nSimple cloth footwear."

static var _boots_texture: Texture2D = null

static func get_boots_texture() -> Texture2D:
	if _boots_texture == null:
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var cloth = Color(0.5, 0.45, 0.35)
		var dark = Color(0.38, 0.33, 0.25)
		var highlight = Color(0.6, 0.55, 0.45)
		# Left boot (shifted up to visually center in 32x32 tile)
		for y in range(14, 22):
			for x in range(8, 14):
				img.set_pixel(x, y, cloth)
		# Right boot
		for y in range(14, 22):
			for x in range(18, 24):
				img.set_pixel(x, y, cloth)
		# Soles
		for x in range(8, 14):
			img.set_pixel(x, 21, dark)
		for x in range(18, 24):
			img.set_pixel(x, 21, dark)
		# Highlights
		for y in range(15, 18):
			img.set_pixel(9, y, highlight)
			img.set_pixel(19, y, highlight)
		_boots_texture = ImageTexture.create_from_image(img)
	return _boots_texture

func get_shared_texture() -> Texture2D:
	return get_boots_texture()

func finish_drop():
	if try_equip_in_ui():
		return
	if is_mouse_over_ui():
		global_position = original_position
		return
	super.finish_drop()

func try_equip_in_ui() -> bool:
	var equip_menu = get_tree().get_root().find_child("EquipmentMenu", true, false)
	if equip_menu == null:
		return false
	if equip_menu.has_method("try_equip_boots_from_world"):
		return equip_menu.try_equip_boots_from_world(self)
	return false

func is_mouse_over_ui() -> bool:
	var viewport = get_viewport()
	if viewport == null:
		return false
	var hovered = viewport.gui_get_hovered_control()
	return hovered != null
