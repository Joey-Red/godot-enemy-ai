class_name EnemyCombatComponent
extends Node

signal on_attack_performed

@export_group("Stats")
@export var damage: float = 10.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5

@export_group("References")
@export var actor: Node3D 

# --- RANGED DATA ---
var projectile_scene: PackedScene = null
var projectile_speed: float = 0.0

# Mask 1 is usually "World/Walls". Adjust this if your walls are on a different layer!
@export_flags_3d_physics var los_collision_mask: int = 1 

var target: Node3D
var _can_attack: bool = true
var _timer: Timer
var muzzle_point: Marker3D

func _ready():
	_timer = Timer.new()
	_timer.wait_time = attack_cooldown
	_timer.one_shot = true
	_timer.timeout.connect(_on_cooldown_finished)
	add_child(_timer)

func initialize(new_damage: float, new_range: float, new_rate: float, proj_scene: PackedScene = null, proj_speed: float = 0.0):
	damage = new_damage
	attack_range = new_range
	attack_cooldown = new_rate
	projectile_scene = proj_scene
	projectile_speed = proj_speed
	if _timer: _timer.wait_time = attack_cooldown

func set_target(new_target: Node3D):
	target = new_target

func _on_cooldown_finished():
	_can_attack = true

# --- NEW FUNCTION: CHECK LINE OF SIGHT ---
func has_line_of_sight() -> bool:
	if not target or not is_instance_valid(target):
		return false
		
	var start_pos = actor.global_position + Vector3(0, 1.5, 0)
	if muzzle_point:
		start_pos = muzzle_point.global_position
	var end_pos = target.global_position + Vector3(0, 1.0, 0) 

	var space_state = actor.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.exclude = [actor]
	query.collision_mask = los_collision_mask
	
	var result = space_state.intersect_ray(query)
	
	if result:
		if result.collider != target:
			# This prints ONLY when blocked. 
			#print("LOS Blocked by: ", result.collider.name)
			return false 
	#else: 
		#print("has los!")
			
	return true

func try_attack():
	if not _can_attack or not target or not is_instance_valid(target):
		return

	var distance = actor.global_position.distance_to(target.global_position)
	
	if distance <= attack_range:
		# --- NEW CHECK ---
		# If this is a ranged enemy, we MUST check for walls.
		# If no LOS, we return (do nothing), letting the movement code take over.
		if projectile_scene and not has_line_of_sight():
			return
			
		_perform_attack()

func _perform_attack():
	_can_attack = false
	_timer.start()
	on_attack_performed.emit()
	
	if projectile_scene:
		_spawn_projectile()
	else:
		_perform_melee_hit()

func _perform_melee_hit():
	if target.has_method("take_damage"):
		target.take_damage(damage)

func _spawn_projectile():
	if not projectile_scene: return
	var new_proj = projectile_scene.instantiate()
	get_tree().current_scene.add_child(new_proj)
	
	if muzzle_point:
		new_proj.global_transform = muzzle_point.global_transform
	else:
		new_proj.global_position = actor.global_position + Vector3(0, 1.5, 0)
	
	# Look at target chest
	new_proj.look_at(target.global_position + Vector3(0, 1.0, 0))
	
	# Initialize projectile logic if it exists
	if new_proj.has_method("initialize"):
		new_proj.initialize(damage, projectile_speed)
