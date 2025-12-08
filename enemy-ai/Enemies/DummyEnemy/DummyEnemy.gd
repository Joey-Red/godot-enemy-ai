class_name DummyEnemy
extends CharacterBody3D

# --- 1. DATA RESOURCE ---
@export var stats: EnemyStats 

# --- 2. SETTINGS ---
@export_group("Settings")
@export var auto_respawn: bool = false 
@export var respawn_time: float = 3.0

# --- 3. COMPONENT REFERENCES ---
@export_group("References")
@export var health_component: HealthComponent
@export var movement_component: EnemyMovementComponent
@export var combat_component: EnemyCombatComponent 
@export var visuals_container: Node3D 
@export var collision_shape: CollisionShape3D
@onready var health_bar = $EnemyHealthbar3D

# --- 4. STATE MACHINE & TIMERS ---
enum State { IDLE, CHASE, ATTACK, DEAD, RESPAWNING }
var current_state: State = State.IDLE

var attack_timer: float = 0.0 
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player_target: Node3D

# --- NEW VARS FOR STRAFING & FLYING ---
var strafe_dir: int = 1 # 1 for Right, -1 for Left
var strafe_timer: float = 0.0
var flight_offset_time: float = 0.0 # For the sine wave bobbing

# --- 5. ANIMATION SYSTEM ---
var _animation_players: Array[AnimationPlayer] = []

# --- SETUP ---
func _ready():
	if stats:
		initialize_from_stats()
	else:
		push_error("CRITICAL: No EnemyStats resource assigned to " + name)
		return

	if health_component:
		health_component.on_death.connect(_on_death)
		health_component.on_damage_taken.connect(_on_hit)
		health_component.on_health_changed.connect(_update_ui)
		_update_ui(health_component.current_health, health_component.max_health)
		
	if combat_component:
		combat_component.on_attack_performed.connect(_on_attack_visuals)

	if movement_component and movement_component.nav_agent:
		if not movement_component.nav_agent.velocity_computed.is_connected(_on_velocity_computed):
			movement_component.nav_agent.velocity_computed.connect(_on_velocity_computed)

	SignalBus.player_spawned.connect(_on_player_spawned)
	SignalBus.player_died.connect(_on_player_died)
	
	# Randomize strafe direction initially so they don't all move the same way
	strafe_dir = 1 if randf() > 0.5 else -1
	
	await get_tree().physics_frame
	find_player()

# --- INITIALIZATION ---
func initialize_from_stats():
	if stats.is_flying:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		axis_lock_linear_y = false 
		# Randomize flight offset so they don't bob in sync
		flight_offset_time = randf() * 10.0
	else:
		motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

	if health_component: health_component.initialize(stats.max_health)
	if movement_component: movement_component.initialize(stats.move_speed, stats.acceleration)
	
	if combat_component:
		var proj_scene = null
		var proj_speed = 0.0
		if "projectile_scene" in stats:
			proj_scene = stats.projectile_scene
			proj_speed = stats.projectile_speed
			
		combat_component.initialize(stats.attack_damage, stats.attack_range, stats.attack_rate, proj_scene, proj_speed)
		
	if stats.model_scene and visuals_container:
		for child in visuals_container.get_children():
			child.queue_free()
		
		var new_model = stats.model_scene.instantiate()
		visuals_container.add_child(new_model)
		visuals_container.scale = Vector3.ONE * stats.scale
		
		_animation_players.clear()
		_find_all_animation_players(new_model)

	if collision_shape:
		collision_shape.scale = Vector3.ONE * stats.scale
	if "model_rotation_y" in stats and visuals_container and visuals_container.get_child_count() > 0:
		visuals_container.get_child(0).rotation_degrees.y = stats.model_rotation_y
	if health_component:
		_update_ui(health_component.current_health, health_component.max_health)

func _find_all_animation_players(node: Node):
	if node is AnimationPlayer:
		_animation_players.append(node)
	for child in node.get_children():
		_find_all_animation_players(child)

func play_animation(anim_name: String):
	if _animation_players.is_empty() or anim_name == "":
		return
	for anim_player in _animation_players:
		if anim_player.has_animation(anim_name):
			anim_player.play(anim_name, 0.2) 
			return

func take_damage(amount: float): 
	if health_component:
		health_component.take_damage(amount)
	
	# Only play hit reaction if NOT dead
	if current_state != State.DEAD and "anim_hit" in stats:
		play_animation(stats.anim_hit)

# --- PHYSICS LOOP ---
func _physics_process(delta):
	if not stats: return 

	# 1. DEAD CHECK
	if current_state == State.DEAD:
		if not stats.is_flying and not is_on_floor():
			velocity.y -= gravity * delta
			velocity.x = 0 
			velocity.z = 0
			move_and_slide()
		return

	# 2. GRAVITY
	if not stats.is_flying and not is_on_floor():
		velocity.y -= gravity * delta

	# 3. TIMERS
	if attack_timer > 0:
		attack_timer -= delta
		
	# Update flight bobbing timer
	flight_offset_time += delta

	# 4. STATE MACHINE
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
	
	_update_animation_state()
	
	# 5. MOVEMENT
	var use_avoidance = false
	if movement_component and movement_component.nav_agent:
		if movement_component.nav_agent.avoidance_enabled:
			use_avoidance = true

	if use_avoidance:
		movement_component.nav_agent.set_velocity(velocity)
	else:
		move_and_slide()

# --- AVOIDANCE CALLBACK ---
func _on_velocity_computed(safe_velocity: Vector3):
	if stats.is_flying:
		velocity = safe_velocity
	else:
		var stored_y = velocity.y
		velocity = safe_velocity
		velocity.y = stored_y
	move_and_slide()

# --- STATE LOGIC ---

func _process_idle(_delta):
	velocity.x = move_toward(velocity.x, 0, 1.0)
	velocity.z = move_toward(velocity.z, 0, 1.0)
	if stats.is_flying:
		velocity.y = move_toward(velocity.y, 0, 1.0)
	
	if player_target and is_instance_valid(player_target):
		current_state = State.CHASE

func _process_chase(delta):
	if not player_target or not is_instance_valid(player_target):
		current_state = State.IDLE
		player_target = null 
		return

	var distance = global_position.distance_to(player_target.global_position)
	
	if stats.is_flying:
		# --- FLYER LOGIC: Bobbing & Height Adjustment ---
		# We use Sine wave to make them bob up and down naturally.
		# This helps them find new LOS angles if they are stuck.
		var bob_amount = sin(flight_offset_time * 2.0) * 1.5 
		var base_height = 4.0
		
		var target_pos = player_target.global_position + Vector3(0, base_height + bob_amount, 0)
		var direction = (target_pos - global_position).normalized()
		
		var turn_rate = stats.turn_speed if "turn_speed" in stats else 5.0
		velocity = velocity.lerp(direction * stats.move_speed, turn_rate * delta)
		_rotate_smoothly(velocity, delta)
		
	else:
		if movement_component:
			var chase_velocity = movement_component.get_chase_velocity()
			velocity.x = move_toward(velocity.x, chase_velocity.x, stats.acceleration * delta)
			velocity.z = move_toward(velocity.z, chase_velocity.z, stats.acceleration * delta)
			_rotate_smoothly(velocity, delta)

	# Transition Check
	var range_check = stats.attack_range if stats else 1.5
	
	if distance <= range_check:
		# CHECK LOS BEFORE ATTACKING
		var has_los = true
		if combat_component:
			has_los = combat_component.has_line_of_sight()
		
		if has_los:
			current_state = State.ATTACK
			# Pick a new strafe direction when we start attacking
			strafe_dir = 1 if randf() > 0.5 else -1
		else:
			# NO LOS: Stay in Chase (Navigation will try to path around wall)
			current_state = State.CHASE

func _process_attack(delta):
	# 1. Calculate direction to player
	if not player_target or not is_instance_valid(player_target):
		current_state = State.IDLE
		player_target = null
		return

	var dir_to_player = (player_target.global_position - global_position).normalized()

	# --- STRAFING LOGIC ---
	if attack_timer > 0:
		# We are in cooldown. Shuffle sideways.
		
		# Calculate "Right" vector relative to looking at player
		var right_vec = dir_to_player.cross(Vector3.UP).normalized()
		
		# Move Left or Right based on strafe_dir
		# REDUCED SPEED: 0.25 makes it a "shuffle" so foot sliding is less obvious
		var strafe_vel = right_vec * strafe_dir * (stats.move_speed * 0.25)
		
		velocity.x = move_toward(velocity.x, strafe_vel.x, stats.acceleration * delta)
		velocity.z = move_toward(velocity.z, strafe_vel.z, stats.acceleration * delta)
		
		# --- VISUAL TRICK: LEAN INTO THE TURN ---
		# Instead of looking DEAD ON at the player, look slightly towards movement.
		# This makes the "Run" animation look more like a diagonal step.
		var look_bias = right_vec * strafe_dir * 0.5 
		var look_target = dir_to_player + look_bias
		_rotate_smoothly(look_target, delta)

		# Randomly switch direction
		if randf() < 0.02: 
			strafe_dir *= -1
			
	else:
		# --- ATTACK MOMENT ---
		# Stop moving to fire (plants feet)
		velocity.x = move_toward(velocity.x, 0, 1.0)
		velocity.z = move_toward(velocity.z, 0, 1.0)
		
		# Look DIRECTLY at player to shoot
		_rotate_smoothly(dir_to_player, delta)
		
		if combat_component:
			combat_component.try_attack() 
			# NOTE: We trigger the animation here, but _update_animation_state handles the rest
			if "anim_attack" in stats:
				play_animation(stats.anim_attack)
			
			attack_timer = stats.attack_rate if stats else 1.0
			strafe_dir *= -1

	# Flyer Logic
	if stats.is_flying:
		velocity.y = move_toward(velocity.y, 0, 1.0)

	# Exit Logic (Range/LOS)
	var distance = global_position.distance_to(player_target.global_position)
	var range_check = stats.attack_range if stats else 1.5
	var lost_sight = false
	if combat_component and not combat_component.has_line_of_sight():
		lost_sight = true

	if distance > range_check + 0.5 or lost_sight: 
		current_state = State.CHASE
# --- HELPERS ---
func _rotate_smoothly(target_direction: Vector3, delta: float):
	var horizontal_dir = Vector3(target_direction.x, 0, target_direction.z)
	if horizontal_dir.length_squared() < 0.001: return
	var target_look_pos = global_position + horizontal_dir
	var current_transform = global_transform
	var target_transform = current_transform.looking_at(target_look_pos, Vector3.UP)
	var current_y = rotation.y
	var target_y = target_transform.basis.get_euler().y
	var turn_speed = stats.turn_speed if "turn_speed" in stats else 10.0
	rotation.y = lerp_angle(current_y, target_y, turn_speed * delta)

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_target = players[0]
		if movement_component: movement_component.set_target(player_target)
		if combat_component: combat_component.set_target(player_target)
		if current_state == State.IDLE:
			current_state = State.CHASE

func _on_attack_visuals():
	if visuals_container:
		var tween = create_tween()
		tween.tween_property(visuals_container, "position", Vector3(0, 0, -0.5), 0.1).as_relative()
		tween.tween_property(visuals_container, "position", Vector3(0, 0, 0.5), 0.2).as_relative()
	if stats:
		SignalBus.enemy_attack_occurred.emit(self, stats.attack_damage)

func _on_hit(_amount):
	_update_ui(health_component.current_health, health_component.max_health)
	if not "anim_hit" in stats or stats.anim_hit == "":
		if visuals_container:
			var tween = create_tween()
			tween.tween_property(visuals_container, "scale", Vector3(1.1, 0.9, 1.1), 0.1)
			tween.tween_property(visuals_container, "scale", Vector3.ONE * (stats.scale if stats else 1.0), 0.1)

func _update_animation_state():
	if _animation_players.is_empty() or not stats: return

	match current_state:
		State.IDLE:
			play_animation(stats.anim_idle)
		State.CHASE:
			play_animation(stats.anim_move) 
		State.DEAD:
			play_animation(stats.anim_death)
		State.ATTACK:
			# --- SMART COMBAT ANIMATION ---
			var is_swinging = false
			
			# Check if the ACTUAL attack animation is currently playing
			for anim in _animation_players:
				if anim.current_animation == stats.anim_attack and anim.is_playing():
					is_swinging = true
					break
			
			# PRIORITY 1: If we are mid-swing, do NOT change anything. Let it finish.
			if is_swinging:
				return
				
			# PRIORITY 2: If we are NOT swinging, but we ARE moving (Strafing), play Run/Move.
			if velocity.length() > 0.1:
				play_animation(stats.anim_move)
			else:
				# PRIORITY 3: Standing still waiting to shoot? Play Idle.
				play_animation(stats.anim_idle)

func _update_ui(current, max_hp):
	if health_bar:
		var safe_max = max(1.0, max_hp)
		health_bar.update_bar(current, safe_max)

func _on_death():
	if current_state == State.DEAD: return
	current_state = State.DEAD
	SignalBus.enemy_died.emit(self)
	_update_animation_state()
	velocity = Vector3.ZERO
	if auto_respawn:
		current_state = State.RESPAWNING
		await get_tree().create_timer(respawn_time).timeout
		respawn()
	else:
		await get_tree().create_timer(1.5).timeout
		if collision_shape: collision_shape.set_deferred("disabled", true)
		if visuals_container:
			var tween = create_tween()
			tween.tween_property(visuals_container, "position:y", -2.0, 2.0)
			await tween.finished
		queue_free()

func respawn():
	health_component.reset_health()
	if visuals_container:
		visuals_container.visible = true
		visuals_container.scale = Vector3.ONE * (stats.scale if stats else 1.0)
	collision_shape.set_deferred("disabled", false)
	_update_ui(health_component.current_health, health_component.max_health)
	current_state = State.IDLE
	find_player()

func _on_player_spawned(): find_player()
func _on_player_died():
	player_target = null
	current_state = State.IDLE
