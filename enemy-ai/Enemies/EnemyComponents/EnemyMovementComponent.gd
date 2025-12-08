class_name EnemyMovementComponent
extends Node

@export_group("Settings")
@export var speed: float = 4.0
@export var acceleration: float = 10.0 # Added to match Resource/BaseEnemy usage
#@export var aggro_range: float = 1000 # Essentially infinite
@export var aggro_range: float = 10.0
@export var stop_distance: float = 1.5 # How close to get before stopping to attack

@export_group("References")
@export var actor: CharacterBody3D
@export var nav_agent: NavigationAgent3D
#@export var deaggro_range: float = 1025.0 #essentially infinite
@export var deaggro_range: float = 15 # Must be larger than aggro_range

var target: Node3D = null

func _ready():
	# Optimize path updates (don't calculate every single frame)
	var timer = Timer.new()
	timer.wait_time = 0.2 # Update path 5 times a second
	timer.autostart = true
	timer.timeout.connect(_update_path_target)
	add_child(timer)
	nav_agent.path_desired_distance = 1.0 
	nav_agent.target_desired_distance = 1.0
	
	#nav_agent.debug_enabled = true

# --- NEW FUNCTION FOR RESOURCE SYSTEM ---
func initialize(new_speed: float, new_accel: float):
	speed = new_speed
	acceleration = new_accel
	# Note: If you want to sync 'stop_distance' with 'attack_range' from the stats,
	# you could add a third argument here, but usually keeping stop_distance
	# separate is fine (you want to stop slightly closer than your max attack range).

func set_target(new_target: Node3D):
	target = new_target

func _update_path_target():
	if target and is_instance_valid(target):
		nav_agent.target_position = target.global_position

func get_chase_velocity(preserve_height: bool = false) -> Vector3:
	if not target or not is_instance_valid(target):
		return Vector3.ZERO
		
	var distance = actor.global_position.distance_to(target.global_position)
	
	# --- LOGIC FIX START ---
	
	# 1. STOPPING LOGIC (Hysteresis)
	# Only stop if we are WAY too far (deaggro_range), NOT just aggro_range.
	# We also check if we are ALREADY chasing (using nav_agent.is_target_reachable() or just distance)
	if distance > deaggro_range:
		return Vector3.ZERO

	# 2. STARTING LOGIC
	# If we aren't moving yet, check the smaller aggro_range
	# (Checking if velocity is effectively zero implies we are currently idle)
	if actor.velocity.length_squared() < 0.1 and distance > aggro_range:
		return Vector3.ZERO
	
	# --- LOGIC FIX END ---
		
	# If we are close enough to attack, stop moving 
	if distance <= stop_distance:
		return Vector3.ZERO

	# 3. Path Calculation (Standard)
	var next_path_position = nav_agent.get_next_path_position()
	var current_position = actor.global_position
	var direction = (next_path_position - current_position).normalized()
	var new_velocity = direction * speed
	# 4. CORNER STUCK FIX (Safe Velocity)
	# Sometimes the next point is weirdly close. If direction is broken, return zero to avoid NaN errors.
	if not preserve_height:
		new_velocity.y = 0 
	
	return new_velocity
	#if direction.is_finite():
		#var new_velocity = direction * speed
		#new_velocity.y = 0 
		#return new_velocity
	#else:
		#return Vector3.ZERO

func look_at_target():
	if target and is_instance_valid(target):
		var target_pos = target.global_position
		target_pos.y = actor.global_position.y # Flatten height
		
		# FIX: Check squared distance (faster than distance) to avoid zero-length vector errors
		# 0.001 is a tiny safety margin
		if actor.global_position.distance_squared_to(target_pos) > 0.001:
			actor.look_at(target_pos, Vector3.UP)
			
			
