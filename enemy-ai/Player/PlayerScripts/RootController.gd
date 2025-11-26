class_name PlayerController
extends CharacterBody3D

# The Root script acts as the central hub. 
# It exposes the body to components but contains NO logic itself.
signal on_player_died
# References to components for easy access if needed externally
@onready var movement = $Components/Movement
@onready var combat = $Components/Combat
@onready var camera_rig = $Head/Camera3D
@onready var health = $Components/HealthComponent
@onready var AnimPlayer = $AnimationPlayer
@onready var AnimTree = $AnimationTree
func _ready():
	# Lock mouse for FPS
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if health:
		health.on_death.connect(_on_death_logic)#respawn player..
# We use the built-in physics process, but we delegate the WORK to components
func _physics_process(delta):
	# Components allow us to simply "ask" them to do their job
	movement.handle_movement(delta)
	
	# The movement component calculates velocity, but the Body must apply it
	move_and_slide()
# Add this function to PlayerController so enemies can damage YOU
func take_damage(amount):
	health.take_damage(amount)

func _on_death_logic():
	
	on_player_died.emit()
	set_physics_process(false)
	# Do animation
	AnimTree["parameters/LifeState/transition_request"] = "dead"
	AnimPlayer.stop()
	
	SignalBus.player_died.emit()
	await get_tree().create_timer(2.0).timeout
	queue_free()
