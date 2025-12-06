#class_name DummyEnemy
#extends CharacterBody3D
#
## --- 1. DATA RESOURCE ---
#@export var stats: EnemyStats # <--- The Data Container
#
## --- 2. SETTINGS ---
#@export_group("Settings")
#@export var auto_respawn: bool = true
#@export var respawn_time: float = 3.0
#
## --- 3. COMPONENT REFERENCES ---
#@export_group("References")
#@export var health_component: HealthComponent
#@export var movement_component: EnemyMovementComponent
#@export var combat_component: EnemyCombatComponent 
#@export var visuals_container: Node3D 
#@export var collision_shape: CollisionShape3D
#@onready var health_bar = $EnemyHealthbar3D
#
## --- 4. STATE MACHINE & TIMERS ---
#enum State { IDLE, CHASE, ATTACK, DEAD, RESPAWNING }
#var current_state: State = State.IDLE
#
#var attack_timer: float = 0.0 # Code-based timer
#var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
#var player_target: Node3D
#var GeneralAnimations: AnimationPlayer
#var MovementAnimations: AnimationPlayer
#
## --- SETUP ---
#func _ready():
	## A. Initialize Components using the Resource Data
	#if stats:
		#initialize_from_stats()
	#else:
		#push_warning("No EnemyStats resource assigned to " + name)
#
	## B. Connect Component Signals
	#if health_component:
		#health_component.on_death.connect(_on_death)
		#health_component.on_damage_taken.connect(_on_hit)
		#health_component.on_health_changed.connect(_update_ui)
		## Initialize UI immediately
		#_update_ui(health_component.current_health, health_component.max_health)
		#
	#if combat_component:
		## Connect to your existing visual tween logic
		#combat_component.on_attack_performed.connect(_on_attack_visuals)
#
	## C. Global Signals
	#SignalBus.player_spawned.connect(_on_player_spawned)
	#SignalBus.player_died.connect(_on_player_died)
		#
	## D. Find Player
	#call_deferred("find_player")
#
## --- INITIALIZATION LOGIC (The "Brain") ---
#func initialize_from_stats():
	## 0. NEW: Set Physics Mode based on flying
	## Floating mode stops the physics engine from trying to snap them to the floor/walls
	#if stats.is_flying:
		#motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		#axis_lock_linear_y = false # Ensure they can move up/down
	#else:
		#motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
#
	## 1. Initialize Components (Same as before)
	#if health_component: health_component.initialize(stats.max_health)
	#if movement_component: movement_component.initialize(stats.move_speed, stats.acceleration)
	#
	#if combat_component:
		## Check for Hybrid/Mage stats
		#var proj_scene = null
		#var proj_speed = 0.0
		#
		## Safe check: Does the resource actually have these fields?
		#if "projectile_scene" in stats:
			#proj_scene = stats.projectile_scene
			#proj_speed = stats.projectile_speed
			#
		#combat_component.initialize(
			#stats.attack_damage, 
			#stats.attack_range, 
			#stats.attack_rate,
			#proj_scene, # Pass the scene (or null)
			#proj_speed  # Pass the speed (or 0.0)
		#)
		#
	## LOAD THE VISUALS
	#if stats.model_scene and visuals_container:
		## Clear old models
		#for child in visuals_container.get_children():
			#child.queue_free()
		#
		## Instantiate new one
		#var new_model = stats.model_scene.instantiate()
		#visuals_container.add_child(new_model)
		#
		## Apply Scale to the CONTAINER, not the mesh
		#visuals_container.scale = Vector3.ONE * stats.scale
		#
		## Find Animation Player
		#var _GeneralAnimations = find_animation_player(new_model, "GeneralAnimations")
		#if _GeneralAnimations:
			#GeneralAnimations = _GeneralAnimations
		#var _MovementAnimations = find_animation_player(new_model, "MovementAnimations")
		#if _MovementAnimations:
			#MovementAnimations = _MovementAnimations
	#
	## NEW: Apply Scale to Collision Box too!
	#if collision_shape:
		#collision_shape.scale = Vector3.ONE * stats.scale
#
	## Apply rotation offset if defined in stats
	#if "model_rotation_y" in stats and visuals_container and visuals_container.get_child_count() > 0:
		#visuals_container.get_child(0).rotation_degrees.y = stats.model_rotation_y
#
## Helper function to find the animation player in the imported scene
#func find_animation_player(root_node: Node, lookingfor: String) -> AnimationPlayer:
	#for child in root_node.get_children():
		#if child.name == "GeneralAnimations" && lookingfor == "GeneralAnimations":
			#return child
		#elif child.name == "MovementAnimations"  && lookingfor == "MovementAnimations":
			#return child
		## Recursive search in case it's buried deep
		#var found = find_animation_player(child, "Anim") 
		#if found: return found
	#return null
#
## --- MAIN PHYSICS LOOP ---
#func _physics_process(delta):
	## NEW: Apply Gravity ONLY if NOT flying
	#if not stats.is_flying and not is_on_floor():
		#velocity.y -= gravity * delta
#
	## Update Attack Cooldown Timer
	#if attack_timer > 0:
		#attack_timer -= delta
#
	## State Machine Logic
	#match current_state:
		#State.IDLE:
			#_process_idle(delta)
		#State.CHASE:
			#_process_chase(delta)
		#State.ATTACK:
			#_process_attack(delta)
		#State.DEAD, State.RESPAWNING:
			#pass # Do nothing
	#
	#_update_animation_state()
	#move_and_slide()
#
## --- STATE FUNCTIONS ---
#
#func _process_idle(_delta):
	## Slow down to a stop
	#velocity.x = move_toward(velocity.x, 0, 1.0)
	#velocity.z = move_toward(velocity.z, 0, 1.0)
	#
	## NEW: If flying, also slow down vertical movement so we don't drift forever
	#if stats.is_flying:
		#velocity.y = move_toward(velocity.y, 0, 1.0)
	#
	## Transition: If we have a target, start chasing
	#if player_target and is_instance_valid(player_target):
		#current_state = State.CHASE
#
#func _process_chase(delta):
	#if not player_target or not is_instance_valid(player_target):
		#current_state = State.IDLE
		#player_target = null 
		#return
#
	## 1. Get Distance
	#var distance = global_position.distance_to(player_target.global_position)
	#
	## 2. Move (Branching Logic for Flying vs Ground)
	#if stats.is_flying:
		## --- FLYING MOVEMENT LOGIC ---
		## Aim slightly above player (e.g. head height)
		#var target_pos = player_target.global_position + Vector3(0, 1.5, 0)
		#var direction = (target_pos - global_position).normalized()
		#
		## Interpolate velocity for smooth flying
		## Use stats.turn_speed if you added it, otherwise default to 5.0
		#var turn_rate = stats.turn_speed if "turn_speed" in stats else 5.0
		#velocity = velocity.lerp(direction * stats.move_speed, turn_rate * delta)
		#
		## Flying Rotation (Look at target)
		#if direction.length() > 0.001:
			#var look_pos = player_target.global_position
			#look_pos.y = global_position.y # Keep visuals upright-ish
			#look_at(look_pos, Vector3.UP)
	#else:
		## --- GROUND MOVEMENT LOGIC (Original) ---
		#if movement_component:
			#var chase_velocity = movement_component.get_chase_velocity()
			#velocity.x = chase_velocity.x
			#velocity.z = chase_velocity.z
			#movement_component.look_at_target()
#
	## 3. Transition: Attack if close enough
	## Use the stats.attack_range for the check
	#var range_check = stats.attack_range if stats else 1.5
	#if distance <= range_check:
		#current_state = State.ATTACK
#
#func _process_attack(_delta):
	## Stop moving while attacking
	#velocity.x = move_toward(velocity.x, 0, 1.0)
	#velocity.z = move_toward(velocity.z, 0, 1.0)
	#
	## NEW: Stop flying drift during attack
	#if stats.is_flying:
		#velocity.y = move_toward(velocity.y, 0, 1.0)
	#
	#if not player_target or not is_instance_valid(player_target):
		#current_state = State.IDLE
		#player_target = null
		#return
#
	## Face the player even while attacking
	## Simple LookAt for flyers, Component for ground
	#if stats.is_flying:
		#var look_pos = player_target.global_position
		#look_pos.y = global_position.y
		#look_at(look_pos, Vector3.UP)
	#elif movement_component:
		#movement_component.look_at_target()
	#
	## Try to Attack
	#if attack_timer <= 0:
		#if combat_component:
			#combat_component.try_attack() 
			#
			## --- Trigger Attack Animation ---
			#if GeneralAnimations and GeneralAnimations.has_animation("Throw"):
				#GeneralAnimations.stop() 
				#GeneralAnimations.play("Throw", 0.1)
			#elif MovementAnimations and MovementAnimations.has_animation("Throw"):
				#MovementAnimations.stop() 
				#MovementAnimations.play("Throw", 0.1)
				#
			#attack_timer = stats.attack_rate if stats else 1.0
#
	## CHECK: Did the player die during the attack?
	#if not player_target or not is_instance_valid(player_target):
		#current_state = State.IDLE
		#player_target = null
		#return
#
	## Transition: Go back to chase if player runs away
	#var distance = global_position.distance_to(player_target.global_position)
	#var range_check = stats.attack_range if stats else 1.5
	#
	## Add buffer (0.5) to prevent jittering
	#if distance > range_check + 0.5: 
		#current_state = State.CHASE
#
## --- HELPER FUNCTIONS ---
#
#func find_player():
	#var players = get_tree().get_nodes_in_group("player")
	#if players.size() > 0:
		#player_target = players[0]
		## Update components with the target
		#if movement_component: movement_component.set_target(player_target)
		#if combat_component: combat_component.set_target(player_target)
		#
		#if current_state == State.IDLE:
			#current_state = State.CHASE
#
#func take_damage(amount: float): # Updated to float to match component
	#if health_component:
		#health_component.take_damage(amount)
	#play_anim_safe("Hit_A", GeneralAnimations)
#
#
#func _on_attack_visuals():
	## Move the whole container
	#if visuals_container:
		#var tween = create_tween()
		#tween.tween_property(visuals_container, "position", Vector3(0, 0, -0.5), 0.1).as_relative()
		#tween.tween_property(visuals_container, "position", Vector3(0, 0, 0.5), 0.2).as_relative()
	#
	#if stats:
		#SignalBus.enemy_attack_occurred.emit(self, stats.attack_damage)
#
#func _on_hit(_amount):
	#_update_ui(health_component.current_health, health_component.max_health)
	#
	## Scale the whole container
	#if not GeneralAnimations: #do a little shrink "animation" if there are no general animations (hit flinch)
		#if visuals_container:
			#var tween = create_tween()
			#tween.tween_property(visuals_container, "scale", Vector3(1.1, 0.9, 1.1), 0.1)
			#tween.tween_property(visuals_container, "scale", Vector3.ONE * (stats.scale if stats else 1.0), 0.1)
#
## --- ANIMATION LOGIC ---
#func _update_animation_state():
	## If no model is loaded or no animation player found, skip
	#if not GeneralAnimations and not MovementAnimations: 
		#return
	## We use a simple match to decide which loop to play
	#match current_state:
		#State.IDLE:
			#play_anim_safe("Idle_A", GeneralAnimations)
		#State.CHASE:
			#play_anim_safe("Running_A", MovementAnimations) 
		#State.DEAD:
			#play_anim_safe("Death_A", GeneralAnimations)
#
## Helper to prevent crashes if an animation is missing
#func play_anim_safe(anim_name: String, anim_player):
	#if not anim_player:
		#return
	#if anim_player.has_animation(anim_name):
		## 0.2s blend time makes transitions smooth (no popping)
		#anim_player.play(anim_name, 0.2)
#
#func _update_ui(current, max_hp):
	#if health_bar:
		#health_bar.update_bar(current, max_hp)
#
#func _on_death():
	#current_state = State.DEAD
	#SignalBus.enemy_died.emit(self)
	#
	#velocity = Vector3.ZERO
	#if visuals_container: visuals_container.visible = false
	#collision_shape.set_deferred("disabled", true)
	#
	#if auto_respawn:
		#current_state = State.RESPAWNING
		#await get_tree().create_timer(respawn_time).timeout
		#respawn()
	#else:
		#queue_free()
#
#func respawn():
	#health_component.reset_health()
	#if visuals_container:
		#visuals_container.visible = true
		## Reset scale based on stats
		#visuals_container.scale = Vector3.ONE * (stats.scale if stats else 1.0)
	#
	#collision_shape.set_deferred("disabled", false)
	#_update_ui(health_component.current_health, health_component.max_health)
	#
	#current_state = State.IDLE
	#find_player()
#
#func _on_player_spawned():
	#find_player()
#
#func _on_player_died():
	#player_target = null
	#current_state = State.IDLE
class_name DummyEnemy
extends CharacterBody3D

# --- 1. DATA RESOURCE ---
@export var stats: EnemyStats 

# --- 2. SETTINGS ---
@export_group("Settings")
@export var auto_respawn: bool = true
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
var GeneralAnimations: AnimationPlayer
var MovementAnimations: AnimationPlayer

# --- SETUP ---
func _ready():
	if stats:
		initialize_from_stats()
	else:
		push_warning("No EnemyStats resource assigned to " + name)

	if health_component:
		health_component.on_death.connect(_on_death)
		health_component.on_damage_taken.connect(_on_hit)
		health_component.on_health_changed.connect(_update_ui)
		_update_ui(health_component.current_health, health_component.max_health)
		
	if combat_component:
		combat_component.on_attack_performed.connect(_on_attack_visuals)

	SignalBus.player_spawned.connect(_on_player_spawned)
	SignalBus.player_died.connect(_on_player_died)
	call_deferred("find_player")

# --- INITIALIZATION LOGIC ---
func initialize_from_stats():
	# 0. Physics Mode
	if stats.is_flying:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		axis_lock_linear_y = false 
	else:
		motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

	# 1. Initialize Components
	if health_component: health_component.initialize(stats.max_health)
	if movement_component: movement_component.initialize(stats.move_speed, stats.acceleration)
	
	if combat_component:
		var proj_scene = null
		var proj_speed = 0.0
		if "projectile_scene" in stats:
			proj_scene = stats.projectile_scene
			proj_speed = stats.projectile_speed
			
		combat_component.initialize(stats.attack_damage, stats.attack_range, stats.attack_rate, proj_scene, proj_speed)
		
	# LOAD VISUALS
	if stats.model_scene and visuals_container:
		for child in visuals_container.get_children():
			child.queue_free()
		
		var new_model = stats.model_scene.instantiate()
		visuals_container.add_child(new_model)
		visuals_container.scale = Vector3.ONE * stats.scale
		
		var _GeneralAnimations = find_animation_player(new_model, "GeneralAnimations")
		if _GeneralAnimations: GeneralAnimations = _GeneralAnimations
		var _MovementAnimations = find_animation_player(new_model, "MovementAnimations")
		if _MovementAnimations: MovementAnimations = _MovementAnimations
	
	if collision_shape:
		collision_shape.scale = Vector3.ONE * stats.scale

	if "model_rotation_y" in stats and visuals_container and visuals_container.get_child_count() > 0:
		visuals_container.get_child(0).rotation_degrees.y = stats.model_rotation_y

func find_animation_player(root_node: Node, lookingfor: String) -> AnimationPlayer:
	for child in root_node.get_children():
		if child.name == "GeneralAnimations" && lookingfor == "GeneralAnimations":
			return child
		elif child.name == "MovementAnimations"  && lookingfor == "MovementAnimations":
			return child
		var found = find_animation_player(child, "Anim") 
		if found: return found
	return null

# --- MAIN PHYSICS LOOP ---
func _physics_process(delta):
	if not stats.is_flying and not is_on_floor():
		velocity.y -= gravity * delta

	if attack_timer > 0:
		attack_timer -= delta

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.DEAD, State.RESPAWNING:
			pass 
	
	_update_animation_state()
	move_and_slide()

# --- STATE FUNCTIONS ---

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
	
	# --- MOVEMENT ---
	if stats.is_flying:
		# Fly towards head height
		var target_pos = player_target.global_position + Vector3(0, 1.5, 0)
		var direction = (target_pos - global_position).normalized()
		
		# Smooth Acceleration
		var turn_rate = stats.turn_speed if "turn_speed" in stats else 5.0
		velocity = velocity.lerp(direction * stats.move_speed, turn_rate * delta)
		
		# Rotate smoothly towards VELOCITY
		_rotate_smoothly(velocity, delta)
		
	else:
		if movement_component:
			var chase_velocity = movement_component.get_chase_velocity()
			# Smooth Acceleration for Ground too (Reduces choppiness)
			velocity.x = move_toward(velocity.x, chase_velocity.x, stats.acceleration * delta)
			velocity.z = move_toward(velocity.z, chase_velocity.z, stats.acceleration * delta)
			
			# Rotate smoothly towards VELOCITY
			_rotate_smoothly(velocity, delta)

	# --- ATTACK CHECK ---
	var range_check = stats.attack_range if stats else 1.5
	if distance <= range_check:
		current_state = State.ATTACK

func _process_attack(_delta):
	velocity.x = move_toward(velocity.x, 0, 1.0)
	velocity.z = move_toward(velocity.z, 0, 1.0)
	if stats.is_flying:
		velocity.y = move_toward(velocity.y, 0, 1.0)
	
	if not player_target or not is_instance_valid(player_target):
		current_state = State.IDLE
		player_target = null
		return

	# During attack, rotate smoothly towards PLAYER
	var dir_to_player = (player_target.global_position - global_position)
	_rotate_smoothly(dir_to_player, _delta)
	
	if attack_timer <= 0:
		if combat_component:
			combat_component.try_attack() 
			if GeneralAnimations and GeneralAnimations.has_animation("Throw"):
				GeneralAnimations.stop() 
				GeneralAnimations.play("Throw", 0.1)
			elif MovementAnimations and MovementAnimations.has_animation("Throw"):
				MovementAnimations.stop() 
				MovementAnimations.play("Throw", 0.1)
			attack_timer = stats.attack_rate if stats else 1.0

	if not player_target or not is_instance_valid(player_target):
		current_state = State.IDLE
		player_target = null
		return

	var distance = global_position.distance_to(player_target.global_position)
	var range_check = stats.attack_range if stats else 1.5
	if distance > range_check + 0.5: 
		current_state = State.CHASE

func _rotate_smoothly(target_direction: Vector3, delta: float):
	# 1. Isolate horizontal direction (X and Z only)
	var horizontal_dir = Vector3(target_direction.x, 0, target_direction.z)

	# 2. SAFETY CHECK: 
	# If the horizontal direction is basically zero (we are stopped OR moving straight up/down),
	# do NOT try to rotate. This prevents the "looking at self" crash.
	if horizontal_dir.length_squared() < 0.001:
		return

	# 3. Create a look position based on that horizontal direction
	# We add the horizontal offset to our current position
	var target_look_pos = global_position + horizontal_dir
	
	# 4. Calculate the desired rotation
	# looking_at() requires a target different from origin, which we guaranteed above
	var current_transform = global_transform
	var target_transform = current_transform.looking_at(target_look_pos, Vector3.UP)
	
	# 5. Extract Y-Rotation (Yaw) and interpolate
	var current_y = rotation.y
	var target_y = target_transform.basis.get_euler().y
	
	# Use turn_speed from stats, or default to 10.0
	var turn_speed = stats.turn_speed if "turn_speed" in stats else 10.0
	rotation.y = lerp_angle(current_y, target_y, turn_speed * delta)

# --- HELPER FUNCTIONS ---

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_target = players[0]
		if movement_component: movement_component.set_target(player_target)
		if combat_component: combat_component.set_target(player_target)
		if current_state == State.IDLE:
			current_state = State.CHASE

func take_damage(amount: float): 
	if health_component:
		health_component.take_damage(amount)
	play_anim_safe("Hit_A", GeneralAnimations)

func _on_attack_visuals():
	if visuals_container:
		var tween = create_tween()
		tween.tween_property(visuals_container, "position", Vector3(0, 0, -0.5), 0.1).as_relative()
		tween.tween_property(visuals_container, "position", Vector3(0, 0, 0.5), 0.2).as_relative()
	if stats:
		SignalBus.enemy_attack_occurred.emit(self, stats.attack_damage)

func _on_hit(_amount):
	_update_ui(health_component.current_health, health_component.max_health)
	if not GeneralAnimations: 
		if visuals_container:
			var tween = create_tween()
			tween.tween_property(visuals_container, "scale", Vector3(1.1, 0.9, 1.1), 0.1)
			tween.tween_property(visuals_container, "scale", Vector3.ONE * (stats.scale if stats else 1.0), 0.1)

# --- ANIMATION LOGIC ---
func _update_animation_state():
	if not GeneralAnimations and not MovementAnimations: 
		return
	match current_state:
		State.IDLE:
			play_anim_safe("Idle_A", GeneralAnimations)
		State.CHASE:
			play_anim_safe("Running_A", MovementAnimations) 
		State.DEAD:
			play_anim_safe("Death_A", GeneralAnimations)

func play_anim_safe(anim_name: String, anim_player):
	if not anim_player:
		return
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name, 0.2)

func _update_ui(current, max_hp):
	if health_bar:
		health_bar.update_bar(current, max_hp)

func _on_death():
	current_state = State.DEAD
	SignalBus.enemy_died.emit(self)
	velocity = Vector3.ZERO
	if visuals_container: visuals_container.visible = false
	collision_shape.set_deferred("disabled", true)
	if auto_respawn:
		current_state = State.RESPAWNING
		await get_tree().create_timer(respawn_time).timeout
		respawn()
	else:
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

func _on_player_spawned():
	find_player()

func _on_player_died():
	player_target = null
	current_state = State.IDLE
