extends "res://scripts/draggable_item.gd"

signal dropped_on_slot(item)

# World cloth armor item

func _ready():
	super._ready()
	queue_redraw()
	requires_adjacent = true
	pick_rect_offset = -pick_rect_size / 2.0

func _input(event):
	super._input(event)

func _draw():
	var texture = get_armor_texture()
	if texture:
		draw_texture(texture, -texture.get_size() / 2.0)

func get_item_description() -> String:
	return "Cloth Armor\nSimple protective cloth."

static var _armor_texture: Texture2D = null

static func get_armor_texture() -> Texture2D:
	if _armor_texture == null:
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var cloth = Color(0.6, 0.55, 0.45)
		var dark = Color(0.45, 0.4, 0.3)
		var highlight = Color(0.7, 0.65, 0.55)
		# Torso
		for y in range(10, 24):
			for x in range(10, 22):
				img.set_pixel(x, y, cloth)
		# Shoulders
		for y in range(8, 12):
			for x in range(8, 24):
				img.set_pixel(x, y, cloth)
		# Belt
		for y in range(18, 20):
			for x in range(10, 22):
				img.set_pixel(x, y, dark)
		# Highlight
		for y in range(11, 14):
			for x in range(12, 16):
				img.set_pixel(x, y, highlight)
		_armor_texture = ImageTexture.create_from_image(img)
	return _armor_texture

func get_shared_texture() -> Texture2D:
	return get_armor_texture()

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
	if equip_menu.has_method("try_equip_armor_from_world"):
		return equip_menu.try_equip_armor_from_world(self)
	return false

func is_mouse_over_ui() -> bool:
	var viewport = get_viewport()
	if viewport == null:
		return false
	var hovered = viewport.gui_get_hovered_control()
	return hovered != null
