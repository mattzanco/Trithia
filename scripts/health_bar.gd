extends Node2D

# Health bar for displaying character health (Tibia-style)

var character: Node2D = null
var max_health = 100
var current_health = 100

const BAR_WIDTH = 28
const BAR_HEIGHT = 4
const BAR_OFFSET_Y = -28

func _ready():
	# Get the parent character
	character = get_parent()
	
	# Get health values from parent if they exist
	if character.has_meta("max_health"):
		max_health = character.get_meta("max_health")
	if character.has_meta("current_health"):
		current_health = character.get_meta("current_health")
	
	print("[HEALTH BAR] _ready() called for ", character.name if character else "unknown")
	print("[HEALTH BAR] Max health: ", max_health, " Current: ", current_health)
	
	# Set z_index to render on top
	z_index = 100
	
	print("[HEALTH BAR] Created for ", character.name if character else "unknown", " with ", max_health, " max health")

func _process(_delta):
	# Update health value if it changed
	if character:
		if character.has_meta("current_health"):
			var new_health = character.get_meta("current_health")
			if new_health != current_health:
				current_health = new_health
				queue_redraw()

func _draw():
	# Draw black outline
	var bar_pos = Vector2(-BAR_WIDTH / 2, BAR_OFFSET_Y)
	var outline_width = 1
	
	# Draw outline rectangle (black border)
	draw_line(bar_pos, bar_pos + Vector2(BAR_WIDTH, 0), Color.BLACK, outline_width)  # Top
	draw_line(bar_pos + Vector2(BAR_WIDTH, 0), bar_pos + Vector2(BAR_WIDTH, BAR_HEIGHT), Color.BLACK, outline_width)  # Right
	draw_line(bar_pos + Vector2(BAR_WIDTH, BAR_HEIGHT), bar_pos + Vector2(0, BAR_HEIGHT), Color.BLACK, outline_width)  # Bottom
	draw_line(bar_pos, bar_pos + Vector2(0, BAR_HEIGHT), Color.BLACK, outline_width)  # Left
	
	# Draw red background bar
	draw_rect(Rect2(bar_pos, Vector2(BAR_WIDTH, BAR_HEIGHT)), Color.RED)
	
	# Draw green health bar
	var health_percentage = float(current_health) / float(max_health)
	var health_width = BAR_WIDTH * health_percentage
	draw_rect(Rect2(bar_pos, Vector2(health_width, BAR_HEIGHT)), Color.GREEN)

func set_health(health: int):
	current_health = health
	queue_redraw()
	if character:
		character.set_meta("current_health", health)

func take_damage(damage: int):
	set_health(max(0, current_health - damage))
