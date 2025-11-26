class_name HealthComponent
extends Node

# Signals allow other scripts to react without hard-coding dependencies
signal on_health_changed(current_hp: int, max_hp: int)
signal on_damage_taken(amount: int)
signal on_death

@export var max_health: int = 100
@export var start_full: bool = true

var current_health: int

func _ready():
	if start_full:
		current_health = max_health
	else:
		current_health = 0 # Or whatever logic you prefer

func take_damage(amount: int):
	if current_health <= 0:
		return # Already dead

	current_health -= amount
	current_health = max(0, current_health) # Prevent negative HP
	
	on_damage_taken.emit(amount)
	on_health_changed.emit(current_health, max_health)
	
	if current_health == 0:
		die()

func heal(amount: int):
	if current_health <= 0:
		return # Can't heal the dead (usually)
		
	current_health += amount
	current_health = min(current_health, max_health)
	
	on_health_changed.emit(current_health, max_health)

func die():
	on_death.emit()
	
func reset_health():
	current_health = max_health
	on_health_changed.emit(current_health, max_health)
