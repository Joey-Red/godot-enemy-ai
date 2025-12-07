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
var muzzle_point: Marker3D

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
	var new_proj = projectile_scene.instantiate()
	get_tree().current_scene.add_child(new_proj)
	
	# USE THE MARKER
	if muzzle_point:
		new_proj.global_transform = muzzle_point.global_transform
	else:
		# Fallback if no marker set
		new_proj.global_position = actor.global_position + Vector3(0, 1.0, 0)
	
	# Aiming logic...
	new_proj.look_at(target.global_position + Vector3(0, 1.0, 0))
