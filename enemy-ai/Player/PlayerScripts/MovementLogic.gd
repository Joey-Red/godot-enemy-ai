class_name MovementComponent
extends Node

# --- ADD THIS SIGNAL ---
signal on_speed_changed(new_speed: float)

@export_group("Settings")
@export var speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

@export_group("References")
@export var player: CharacterBody3D
@export var head: Node3D
@export var input: InputComponent
@export var animation_tree: AnimationTree 

var _playback: AnimationNodeStateMachinePlayback
var _last_emitted_speed: float = 0.0 # To track changes

func _ready():
	input.on_jump.connect(perform_jump)
	
	if animation_tree:
		_playback = animation_tree.get("parameters/Motion/playback")

func handle_movement(delta: float):
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta

	var direction_2d = input.input_dir
	var direction = (player.transform.basis * Vector3(direction_2d.x, 0, direction_2d.y)).normalized()
	
	# --- LOGIC UPDATE START ---
	var target_speed = speed
	if Input.is_action_pressed("sprint"):
		target_speed = sprint_speed
	
	# Emit signal only if speed changed (Optimization)
	if target_speed != _last_emitted_speed:
		_last_emitted_speed = target_speed
		on_speed_changed.emit(target_speed)
	# --- LOGIC UPDATE END ---

	if direction:
		player.velocity.x = direction.x * target_speed
		player.velocity.z = direction.z * target_speed
		
		if _playback:
			_playback.travel("Run")
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, target_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, target_speed)
		
		if _playback:
			_playback.travel("Idle")

func perform_jump():
	if player.is_on_floor():
		player.velocity.y = jump_velocity
