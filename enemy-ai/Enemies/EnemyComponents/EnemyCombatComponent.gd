class_name EnemyCombatComponent
extends Node

# Signal to tell the main script (or animation player) to play the attack animation
signal on_attack_performed

@export_group("Stats")
@export var damage: float = 10.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5

@export_group("References")
@export var actor: Node3D # The Enemy Root (BaseEnemy)

# --- RANGED DATA ---
var projectile_scene: PackedScene = null
var projectile_speed: float = 0.0

var target: Node3D
var _can_attack: bool = true
var _timer: Timer

func _ready():
	# Create cooldown timer via code
	_timer = Timer.new()
	_timer.wait_time = attack_cooldown
	_timer.one_shot = true
	_timer.timeout.connect(_on_cooldown_finished)
	add_child(_timer)

# --- UPDATED INITIALIZE FUNCTION ---
# We use default values (= null) so this still works for melee enemies too
func initialize(new_damage: float, new_range: float, new_rate: float, proj_scene: PackedScene = null, proj_speed: float = 0.0):
	damage = new_damage
	attack_range = new_range
	attack_cooldown = new_rate
	
	# Store Ranged Data
	projectile_scene = proj_scene
	projectile_speed = proj_speed
	
	# If the timer is already created, we must update its wait_time
	if _timer:
		_timer.wait_time = attack_cooldown

func set_target(new_target: Node3D):
	target = new_target

func _on_cooldown_finished():
	_can_attack = true

func try_attack():
	# 1. Basic Validation
	if not _can_attack or not target or not is_instance_valid(target):
		return

	# 2. Check Distance
	var distance = actor.global_position.distance_to(target.global_position)
	
	# 3. Perform Attack if in range
	if distance <= attack_range:
		_perform_attack()

func _perform_attack():
	_can_attack = false
	_timer.start()
	
	# Emit signal so BaseEnemy can play animation/sound
	on_attack_performed.emit()
	
	# 4. DECIDE ATTACK TYPE
	if projectile_scene:
		_spawn_projectile()
	else:
		_perform_melee_hit()

# --- MELEE LOGIC ---
func _perform_melee_hit():
	# Instant damage application
	if target.has_method("take_damage"):
		target.take_damage(damage)

# --- RANGED LOGIC ---
func _spawn_projectile():
	if not projectile_scene: return
	
	# 1. Instantiate the bullet
	var new_proj = projectile_scene.instantiate()
	
	# 2. Add to the MAIN SCENE (Not the enemy, so it doesn't move with the enemy)
	get_tree().current_scene.add_child(new_proj)
	
	# 3. Position it (Start at head height, e.g., +1.5m up)
	var spawn_pos = actor.global_position
	spawn_pos.y += 1
	new_proj.global_position = spawn_pos
	
	# 4. Aim at target
	# We aim at the target's center (assuming target origin is at feet, we look up slightly)
	var target_aim_pos = target.global_position
	target_aim_pos.y += .5 # Aim for the chest
	new_proj.look_at(target_aim_pos)
	
	# 5. Configure Projectile
	# Requires the projectile script to have an 'initialize' function
	if new_proj.has_method("initialize"):
		new_proj.initialize(damage, projectile_speed)
