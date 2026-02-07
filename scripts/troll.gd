extends "res://scripts/enemy.gd"

# Troll enemy controller

func configure_enemy():
	enemy_name = "Troll"
	max_health = 40
	max_mp = 20
	strength = 6
	intelligence = 4
	dexterity = 5
	speed = 4
	attack_cooldown = 2.8
	detection_range = 650.0
	has_weapon = false
	is_humanoid = true
	
	skin_color = Color(0.55, 0.4, 0.25)
	dark_skin_color = Color(0.4, 0.28, 0.18)
	hair_color = Color(0.25, 0.18, 0.12)
	muscle_shadow_color = Color(0.45, 0.32, 0.22)
	pants_color = Color(0.4, 0.3, 0.2)
	outline_color = Color(0.1, 0.1, 0.1)
	metal_color = Color(0.0, 0.0, 0.0, 0.0)
	handle_color = Color(0.0, 0.0, 0.0, 0.0)
