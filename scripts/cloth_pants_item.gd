extends "res://scripts/draggable_item.gd"

signal dropped_on_slot(item)

# World cloth pants item

func _ready():
	super._ready()
	queue_redraw()
	requires_adjacent = true
	pick_rect_offset = -pick_rect_size / 2.0

func _input(event):
	super._input(event)

func _draw():
	var texture = get_pants_texture()
	if texture:
		draw_texture(texture, -texture.get_size() / 2.0)

func get_item_description() -> String:
	return "Cloth Pants\nSimple cloth trousers."

static var _pants_texture: Texture2D = null

static func get_pants_texture() -> Texture2D:
	if _pants_texture == null:
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var cloth = Color(0.55, 0.5, 0.4)
		var dark = Color(0.4, 0.35, 0.28)
		var highlight = Color(0.65, 0.6, 0.5)
		# Waist
		for y in range(8, 10):
			for x in range(10, 22):
				img.set_pixel(x, y, dark)
		# Legs (leave a center gap so it reads as pants, not a skirt)
		for y in range(10, 24):
			for x in range(10, 15):
				img.set_pixel(x, y, cloth)
			for x in range(17, 22):
				img.set_pixel(x, y, cloth)
		# Inner seam shadow
		for y in range(12, 22):
			img.set_pixel(15, y, dark)
			img.set_pixel(16, y, dark)
		# Cuffs
		for x in range(10, 15):
			img.set_pixel(x, 23, dark)
		for x in range(17, 22):
			img.set_pixel(x, 23, dark)
		# Highlights
		for y in range(12, 16):
			for x in range(11, 13):
				img.set_pixel(x, y, highlight)
			for x in range(19, 21):
				img.set_pixel(x, y, highlight)
		_pants_texture = ImageTexture.create_from_image(img)
	return _pants_texture

func get_shared_texture() -> Texture2D:
	return get_pants_texture()

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
	if equip_menu.has_method("try_equip_pants_from_world"):
		return equip_menu.try_equip_pants_from_world(self)
	return false

func is_mouse_over_ui() -> bool:
	var viewport = get_viewport()
	if viewport == null:
		return false
	var hovered = viewport.gui_get_hovered_control()
	return hovered != null
