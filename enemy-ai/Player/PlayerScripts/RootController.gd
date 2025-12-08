class_name PlayerController
extends CharacterBody3D

signal on_player_died

@onready var movement = $Components/Movement
@onready var combat = $Components/Combat
@onready var camera_rig = $Head/Camera3D
@onready var health = $Components/HealthComponent
@onready var AnimPlayer = $AnimationPlayer
@onready var AnimTree = $AnimationTree

# --- NEW VARS FOR FLYING ---
var is_flying: bool = false
var _saved_collision_mask: int = 1

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if health:
		health.on_death.connect(_on_death_logic)

# --- NEW INPUT FUNCTION FOR TOGGLE ---
func _input(event):
	# Toggle with 'P' key
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		is_flying = !is_flying
		if is_flying:
			# Enable Flight: Floating physics, No Collision
			motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
			_saved_collision_mask = collision_mask
			collision_mask = 0 
		else:
			# Disable Flight: Restore Gravity and Collision
			motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
			collision_mask = _saved_collision_mask

func _physics_process(delta):
	# --- MODIFIED LOGIC START ---
	if is_flying:
		# 1. Fly Logic (Direct Input)
		var dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var cam_basis = camera_rig.global_basis
		
		# Move where camera looks
		var target_vel = (cam_basis * Vector3(dir.x, 0, dir.y)).normalized() * 20.0 # 20 is fly speed
		
		# Vertical Movement (Space/Ctrl)
		if Input.is_action_pressed("jump"): target_vel += Vector3.UP * 10.0
		if Input.is_action_pressed("crouch"): target_vel += Vector3.DOWN * 10.0 # Ensure 'crouch' is mapped or use KEY_CTRL
		
		velocity = velocity.lerp(target_vel, 10.0 * delta)
	else:
		# 2. Normal Logic (Delegate to Component)
		movement.handle_movement(delta)
	
	move_and_slide()

func take_damage(amount):
	health.take_damage(amount)

func _on_death_logic():
	on_player_died.emit()
	set_physics_process(false)
	AnimTree["parameters/LifeState/transition_request"] = "dead"
	AnimPlayer.stop()
	SignalBus.player_died.emit()
	await get_tree().create_timer(2.0).timeout
	queue_free()
