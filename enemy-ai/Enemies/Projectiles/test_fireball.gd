class_name Projectile
extends Area3D

# --- CONFIGURATION ---
@export var lifetime: float = 5.0
@export var impact_effect: PackedScene # Optional: Explosion particles

# --- STATE ---
var speed: float = 15.0 # Set by initialize
var damage: float = 10.0 # Set by initialize
var velocity: Vector3 = Vector3.ZERO

func _ready():
	# 1. Setup Collision
	# We connect the signal in code to ensure it's always linked
	body_entered.connect(_on_body_entered)
	
	# 2. Setup Self-Destruct Timer
	# This ensures the projectile doesn't exist forever if it misses
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(_on_lifetime_expired)

# --- INITIALIZATION ---
# Called by EnemyCombatComponent immediately after spawning
func initialize(new_damage: float, new_speed: float):
	damage = new_damage
	speed = new_speed

# --- PHYSICS LOOP ---
func _physics_process(delta):
	# Move "Forward" relative to where the projectile is looking
	# -basis.z is the "Forward" vector in Godot
	var forward_direction = -global_transform.basis.z
	
	# Move the Area3D
	global_position += forward_direction * speed * delta

# --- COLLISION LOGIC ---
func _on_body_entered(body: Node3D):
	# 1. Ignore the enemy that shot it (optional, usually handled by Collision Layers)
	if body is DummyEnemy: 
		return

	# 2. Deal Damage
	# This hooks into your Component system automatically
	if body.has_method("take_damage"):
		body.take_damage(damage)
		# Optional: Tell the SignalBus a hit occurred (if you have this signal)
		# SignalBus.projectile_hit.emit(global_position)
	
	_impact()

func _on_lifetime_expired():
	queue_free()

func _impact():
	# Spawn visual effects if assigned (Explosion)
	if impact_effect:
		var fx = impact_effect.instantiate()
		get_tree().current_scene.add_child(fx)
		fx.global_position = global_position
	
	# Destroy the projectile
	queue_free()
