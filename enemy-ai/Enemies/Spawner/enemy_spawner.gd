class_name EnemySpawner
extends Marker3D

@export_group("Spawner Settings")
@export var enemy_scene: PackedScene
@export var spawn_interval: float = 4.0
@export var spawn_radius: float = 3.0
@export var max_active_enemies: int = 5

var current_enemy_count: int = 0
var spawn_timer: Timer

func _ready():
	# Create and configure a timer automatically via code
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	# Spawn the first one immediately
	call_deferred("_spawn_enemy")

func _on_spawn_timer_timeout():
	if current_enemy_count < max_active_enemies:
		_spawn_enemy()

func _spawn_enemy():
	if not enemy_scene:
		return

	var enemy_instance = enemy_scene.instantiate()
	
	# 1. Calculate random position offset
	var random_x = randf_range(-spawn_radius, spawn_radius)
	var random_z = randf_range(-spawn_radius, spawn_radius)
	var spawn_pos = global_position + Vector3(random_x, 0, random_z)
	
	# 2. Add to scene
	# We add to the parent (the level) so the enemy isn't stuck inside the Spawner node
	get_parent().add_child(enemy_instance)
	enemy_instance.global_position = spawn_pos
	
	# 3. Track enemy count
	current_enemy_count += 1
	
	# 4. Listen for death to decrease count
	if enemy_instance.has_node("Components/HealthComponent"):
		# Connect to the 'on_death' signal of the enemy's health component
		# We use bind() if we wanted to know WHICH enemy died, but here simple math works
		enemy_instance.get_node("Components/HealthComponent").on_death.connect(_on_enemy_death)

func _on_enemy_death():
	current_enemy_count = max(0, current_enemy_count - 1)
