extends Node

# Combat effect creation utilities

static func create_miss_effect(parent: Node, target_pos: Vector2):
	"""Create a smoke puff effect for a missed attack"""
	var effect = MissEffect.new()
	effect.position = target_pos
	effect.z_index = 4096  # Maximum allowed z_index in Godot
	effect.z_as_relative = false  # Absolute z-index, not relative to parent
	parent.add_child(effect)

static func create_blood_effect(parent: Node, target_pos: Vector2, damage: int = 0):
	"""Create a blood spurt effect for a successful hit"""
	var effect = BloodEffect.new()
	effect.position = target_pos
	effect.z_index = 4096  # Maximum allowed z_index in Godot
	effect.z_as_relative = false  # Absolute z-index, not relative to parent
	effect.damage_amount = damage
	parent.add_child(effect)

class MissEffect extends Node2D:
	var lifetime = 0.0
	var max_lifetime = 0.5
	
	func _process(delta):
		lifetime += delta
		if lifetime >= max_lifetime:
			queue_free()
		else:
			queue_redraw()
	
	func _draw():
		var progress = lifetime / max_lifetime
		var alpha = 1.0 - progress
		var size = 8 + (progress * 12)
		
		# Draw expanding smoke puff (gray circles)
		var smoke_color = Color(0.5, 0.5, 0.5, alpha * 0.8)
		draw_circle(Vector2(0, -10), size, smoke_color)
		draw_circle(Vector2(-5, -8), size * 0.8, smoke_color)
		draw_circle(Vector2(5, -8), size * 0.8, smoke_color)
		draw_circle(Vector2(0, -15), size * 0.6, smoke_color)

class BloodEffect extends Node2D:
	var lifetime = 0.0
	var max_lifetime = 1.0
	var particles = []
	var damage_amount = 0
	
	func _ready():
		# Create blood particles
		for i in range(8):
			var angle = (i / 8.0) * TAU
			var speed = randf_range(30, 60)
			particles.append({
				"pos": Vector2.ZERO,
				"vel": Vector2(cos(angle), sin(angle)) * speed,
				"size": randf_range(2, 4)
			})
	
	func _process(delta):
		lifetime += delta
		if lifetime >= max_lifetime:
			queue_free()
		else:
			# Update particles
			for p in particles:
				p.pos += p.vel * delta
				p.vel.y += 100 * delta  # Gravity
			queue_redraw()
	
	func _draw():
		var progress = lifetime / max_lifetime
		var alpha = 1.0 - progress
		
		# Draw blood particles (red droplets)
		var blood_color = Color(0.8, 0.0, 0.0, alpha)
		for p in particles:
			draw_circle(p.pos + Vector2(0, -10), p.size, blood_color)
		
		# Draw damage number floating upward
		if damage_amount > 0:
			var float_offset = progress * -30  # Float upward
			var damage_pos = Vector2(0, -20 + float_offset)
			var damage_color = Color(1.0, 1.0, 0.0, alpha)  # Yellow text
			
			# Draw text outline (black)
			for offset in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_string(ThemeDB.fallback_font, damage_pos + offset, str(damage_amount), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0, 0, 0, alpha))
			
			# Draw text
			draw_string(ThemeDB.fallback_font, damage_pos, str(damage_amount), HORIZONTAL_ALIGNMENT_CENTER, -1, 16, damage_color)
