extends Control

func _ready():
	# Set up the death screen UI
	set_anchors_preset(Control.PRESET_CENTER)
	
	# Store the text to draw
	var death_text = "You Have Died"
	
	# Queue redraw to display the custom text
	queue_redraw()

func _draw():
	var death_text = "You Have Died"
	var font = get_theme_default_font()
	var font_size = 60  # Smaller than the original 96
	
	# Get viewport size for centering
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Calculate text size
	var text_size = font.get_string_size(death_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	# Center position - subtract half the text size
	var text_pos = (viewport_size - text_size) / 2
	
	# Draw black outline by drawing text offset in 8 directions
	var outline_offset = 2
	for ox in range(-outline_offset, outline_offset + 1):
		for oy in range(-outline_offset, outline_offset + 1):
			if ox != 0 or oy != 0:  # Skip center (that's the actual text)
				draw_string(font, text_pos + Vector2(ox, oy), death_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
	
	# Draw white text on top
	draw_string(font, text_pos, death_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
