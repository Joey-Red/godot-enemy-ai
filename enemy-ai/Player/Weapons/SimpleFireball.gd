class_name Fireball
extends Area3D

@export var speed: float = 20.0
@export var rotation_speed: float = 10.0 # How fast it spins
@export var damage: int = 25
@export var lifetime: float = 3.0

func _ready():
	# 1. Connect the signal automatically
	body_entered.connect(_on_body_entered)
	
	# 2. Destroy self after 'lifetime' seconds
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta):
	# Move forward (local negative Z)
	position -= transform.basis.z * speed * delta
	
	# Rotate around local Z axis (Forward) for a "drilling" effect
	rotate_object_local(Vector3.FORWARD, rotation_speed * delta)

func _on_body_entered(body):
	if body.is_in_group("player"):
		return
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# Add particle effect instantiation here if desired
	queue_free()
