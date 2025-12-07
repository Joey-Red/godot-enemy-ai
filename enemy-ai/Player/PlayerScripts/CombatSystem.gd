class_name CombatComponent
extends Node

signal on_damage_multiplier_changed(new_mult: float)

@export var damage_multiplier: float = 1.0:
	set(value):
		damage_multiplier = value
		on_damage_multiplier_changed.emit(damage_multiplier)

@export_group("Settings")
@export var buffer_window: float = 0.2 # How long to remember a button press
@export var fireball_cooldown: float = 0.6 

@export_group("References")
@export var animation_tree: AnimationTree
@export var input: InputComponent
@export var projectile_spawn_point: Node3D
@export var projectile_scene: PackedScene 
@export var camera: Camera3D 

@onready var sword_scene = $"../../RootNode/CharacterArmature/Skeleton3D/WeaponSocket_Normal/Sword"

var can_fireball: bool = true 
var _buffer_timer: float = 0.0
var _queued_action: Callable = Callable() # Stores the function we want to run

func _ready():
	# We connect signals to the BUFFER functions, not the perform functions
	input.on_attack_sword.connect(buffer_sword_attack)
	input.on_attack_fireball.connect(buffer_fireball_attack)
	
	call_deferred("emit_signal", "on_damage_multiplier_changed", damage_multiplier)

func _process(delta: float):
	# 1. Manage Buffer Timer
	if _buffer_timer > 0:
		_buffer_timer -= delta
		
		# 2. Try to Execute Buffered Action
		# We only execute if the animation tree says we are NOT playing an attack
		if not is_animation_busy():
			_queued_action.call()
			_buffer_timer = 0.0 # Consume buffer so we don't double attack

# --- HELPER: The Core of the Logic ---
func is_animation_busy() -> bool:
	# This checks the "active" property of the OneShot node in the AnimationTree.
	# It returns TRUE if the animation is currently playing or blending out.
	return animation_tree.get("parameters/AttackShot/active")

# --- BUFFERING INPUTS ---
func buffer_sword_attack():
	_buffer_timer = buffer_window
	_queued_action = perform_sword_attack

func buffer_fireball_attack():
	_buffer_timer = buffer_window
	_queued_action = perform_fireball

# --- EXECUTION ---
func perform_sword_attack():
	# Double check sword specific logic (optional, but good safety)
	if sword_scene.currently_attacking: return

	animation_tree.set("parameters/AttackType/transition_request", "state_0")
	animation_tree.set("parameters/AttackShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	sword_scene.attack()
		
func perform_fireball():
	# Logic check: cooldown
	if not can_fireball: return
		
	can_fireball = false
	
	animation_tree.set("parameters/AttackType/transition_request", "state_1")
	animation_tree.set("parameters/AttackShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
	if projectile_scene:
		var fireball = projectile_scene.instantiate()
		get_tree().root.add_child(fireball)
		fireball.global_position = projectile_spawn_point.global_position
		
		if camera:
			fireball.global_rotation = camera.global_rotation
		else:
			fireball.global_rotation = projectile_spawn_point.global_rotation

	# Cooldown Management
	# We still use a timer for cooldowns because that's game logic, not animation logic.
	await get_tree().create_timer(fireball_cooldown).timeout
	can_fireball = true
