class_name MovementComponent
extends Node

# --- SIGNALS ---
signal on_speed_changed(new_speed: float)
signal on_slide_start
signal on_slide_end
signal on_crouch_toggle(is_crouched: bool)

@export_group("Settings")
@export var speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_walk_speed: float = 2.5
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
# NEW: How long (in seconds) we "remember" the jump button was pressed before landing
@export var jump_buffer_time: float = 0.15 

@export_group("Slide Settings")
@export var slide_speed_boost: float = 12.0
@export var slide_friction: float = 3.5
@export var slide_min_speed: float = 5.5   
@export var slide_exit_speed: float = 2.0  
@export var crouch_height_offset: float = -0.6
@export var single_roll_duration: float = 0.8 
@export var slide_steering_amount: float = 5.0 

@export var animation_slide_name: String = "Roll"
@export var animation_crouch_name: String = "Crouch" 

@export_group("References")
@export var player: CharacterBody3D
@export var head: Node3D
@export var input: InputComponent
@export var animation_tree: AnimationTree 
@export var combat: CombatComponent

var _playback: AnimationNodeStateMachinePlayback
var _last_emitted_speed: float = 0.0
var _initial_head_y: float = 0.0

# State
var is_sliding: bool = false
var is_crouching: bool = false
var slide_direction: Vector3 = Vector3.ZERO
var _current_slide_timer: float = 0.0
var _jump_buffer_timer: float = 0.0 # NEW: internal timer

func _ready():
	if head: _initial_head_y = head.position.y
	
	# CHANGED: We connect to a buffer request function, not the direct jump
	input.on_jump.connect(_on_jump_request) 
	
	input.on_crouch_press.connect(_on_crouch_press)
	input.on_crouch_release.connect(_on_crouch_release)
	
	if animation_tree: 
		_playback = animation_tree.get("parameters/Motion/playback")

func handle_movement(delta: float):
	# 1. Update Jump Buffer Timer
	if _jump_buffer_timer > 0:
		_jump_buffer_timer -= delta
		
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta

	# 2. Check for Buffered Jump
	# Logic: If we have a fresh jump input "saved" (_jump_buffer_timer > 0)
	# AND we are currently on the floor... Execute the jump immediately.
	if player.is_on_floor() and _jump_buffer_timer > 0:
		perform_jump()

	# --- STATE MACHINE UPDATE ---
	if is_sliding:
		_process_slide_physics(delta)
	elif is_crouching:
		_process_standard_movement(delta, crouch_walk_speed)
	else:
		_process_standard_movement(delta, speed)

# --- INPUT HANDLERS ---

# NEW: Called when InputComponent says "Jump button pressed"
func _on_jump_request():
	# We set the timer. This makes the jump request "valid" for the next 0.15 seconds.
	_jump_buffer_timer = jump_buffer_time

func _on_crouch_press():
	if not player.is_on_floor(): return

	var current_speed = Vector2(player.velocity.x, player.velocity.z).length()
	
	if current_speed > slide_min_speed:
		start_slide()
	else:
		start_crouch()

func _on_crouch_release():
	if is_crouching:
		stop_crouch()

func _process_standard_movement(_delta: float, current_max_speed: float):
	var direction_2d = input.input_dir
	var direction = (player.transform.basis * Vector3(direction_2d.x, 0, direction_2d.y)).normalized()
	
	var target_speed = current_max_speed
	
	if Input.is_action_pressed("sprint") and not is_crouching:
		target_speed = sprint_speed
	
	if target_speed != _last_emitted_speed:
		_last_emitted_speed = target_speed
		on_speed_changed.emit(target_speed)

	if direction:
		player.velocity.x = direction.x * target_speed
		player.velocity.z = direction.z * target_speed
		
		if _playback:
			if is_crouching:
				_playback.travel(animation_crouch_name)
			else:
				_playback.travel("Run")
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, target_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, target_speed)
		
		if _playback:
			if is_crouching:
				_playback.travel(animation_crouch_name)
			else:
				_playback.travel("Idle")

func _process_slide_physics(delta: float):
	_current_slide_timer += delta

	# STEERING LOGIC
	var direction_2d = input.input_dir
	var target_dir = (player.transform.basis * Vector3(direction_2d.x, 0, direction_2d.y)).normalized()
	
	if target_dir:
		var current_speed_val = player.velocity.length()
		var new_velocity = player.velocity.lerp(target_dir * current_speed_val, slide_steering_amount * delta)
		player.velocity.x = new_velocity.x
		player.velocity.z = new_velocity.z

	# FRICTION LOGIC
	player.velocity.x = move_toward(player.velocity.x, 0, slide_friction * delta)
	player.velocity.z = move_toward(player.velocity.z, 0, slide_friction * delta)

	var current_speed = Vector2(player.velocity.x, player.velocity.z).length()
	
	# EXIT CONDITION A: Momentum gone
	if current_speed < slide_exit_speed:
		stop_slide()
		if input.is_crouch_held:
			start_crouch()
		return

	# EXIT CONDITION B: Tap Timer Expired
	if _current_slide_timer > single_roll_duration and not input.is_crouch_held:
		stop_slide()

func start_slide():
	is_sliding = true
	is_crouching = false
	_current_slide_timer = 0.0 
	slide_direction = player.velocity.normalized()
	
	player.velocity.x = slide_direction.x * slide_speed_boost
	player.velocity.z = slide_direction.z * slide_speed_boost
	
	if _playback: _playback.travel(animation_slide_name)
	on_slide_start.emit()

func stop_slide():
	is_sliding = false
	on_slide_end.emit()

func start_crouch():
	is_crouching = true
	is_sliding = false
	if _playback: _playback.travel(animation_crouch_name)
	on_crouch_toggle.emit(true)

func stop_crouch():
	is_crouching = false
	on_crouch_toggle.emit(false)

func perform_jump():
	if combat and combat.is_animation_busy(): 
		return
	
	player.velocity.y = jump_velocity
	
	# Reset the buffer so we don't accidentally double jump if logic changes later
	_jump_buffer_timer = 0.0 
	
	if is_sliding: stop_slide()
	if is_crouching: stop_crouch()
