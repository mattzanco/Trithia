extends "res://scripts/enemy.gd"

# Orc enemy controller

func configure_enemy():
	enemy_name = "Orc"
	max_health = 50
	max_mp = 25
	strength = 8
	intelligence = 6
	dexterity = 7
	speed = 5
	attack_cooldown = 2.5
	detection_range = 700.0
	has_weapon = true
	
	skin_color = Color(0.4, 0.7, 0.4)
	dark_skin_color = Color(0.2, 0.5, 0.2)
	hair_color = Color(0.3, 0.2, 0.1)
	muscle_shadow_color = Color(0.25, 0.55, 0.25)
	pants_color = Color(0.5, 0.4, 0.3)
	outline_color = Color(0.1, 0.1, 0.1)
	metal_color = Color(0.7, 0.7, 0.75)
	handle_color = Color(0.4, 0.3, 0.2)
