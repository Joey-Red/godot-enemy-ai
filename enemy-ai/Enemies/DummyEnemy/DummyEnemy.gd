class_name DummyEnemy
extends CharacterBody3D

@export_group("Settings")
@export var auto_respawn: bool = true
@export var respawn_time: float = 3.0

@export_group("References")
@export var health_component: HealthComponent
@export var movement_component: EnemyMovementComponent
@export var combat_component: EnemyCombatComponent # <--- NEW REFERENCE
@export var visual_mesh: Node3D
@export var collision_shape: CollisionShape3D
@onready var health_bar = $EnemyHealthbar3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player_target: Node3D

# --- DAMAGE INTERFACE ---
func take_damage(amount: int):
	if health_component:
		health_component.take_damage(amount)
		
		# Simple Visual Feedback
		var tween = create_tween()
		tween.tween_property(visual_mesh, "scale", Vector3(1.1, 0.9, 1.1), 0.1)
		tween.tween_property(visual_mesh, "scale", Vector3.ONE, 0.1)

# --- SETUP ---
func _ready():
	# 1. Health
	if health_component:
		health_component.on_death.connect(_on_death)
		health_component.on_damage_taken.connect(_on_hit)
		health_component.on_health_changed.connect(_update_ui)
		_update_ui(health_component.current_health, health_component.max_health)
		SignalBus.player_spawned.connect(_on_player_spawned)
		SignalBus.player_died.connect(_on_player_died)
		
	# 2. Find Player
	call_deferred("find_player")
	
	# 3. Combat Signal
	if combat_component:
		combat_component.on_attack_performed.connect(_on_attack_visuals)

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_target = players[0]
		
		# Give target to components
		if movement_component:
			movement_component.set_target(player_target)
		if combat_component: # <--- GIVE TARGET TO COMBAT
			combat_component.set_target(player_target)

# --- MAIN LOOP ---
func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if player_target and visual_mesh.visible:
		# 1. MOVEMENT
		if movement_component:
			var chase_velocity = movement_component.get_chase_velocity()
			if chase_velocity != Vector3.ZERO:
				velocity.x = chase_velocity.x
				velocity.z = chase_velocity.z
				movement_component.look_at_target()
			else:
				velocity.x = move_toward(velocity.x, 0, movement_component.speed)
				velocity.z = move_toward(velocity.z, 0, movement_component.speed)
		
		# 2. COMBAT (Try to attack every frame)
		if combat_component: # <--- TRY ATTACK
			combat_component.try_attack()
	
	move_and_slide()

# --- CALLBACKS ---
func _on_attack_visuals():
	# Placeholder: Make the enemy lunge forward slightly or flash a different color
	var tween = create_tween()
	tween.tween_property(visual_mesh, "position", Vector3(0, 0, -0.5), 0.1).as_relative()
	tween.tween_property(visual_mesh, "position", Vector3(0, 0, 0.5), 0.2).as_relative()

func _on_hit(_amount):
	_update_ui(health_component.current_health, health_component.max_health)

func _update_ui(current, max_hp):
	if health_bar:
		health_bar.update_bar(current, max_hp)

func _on_death():
	print("Dummy Destroyed!")
	velocity = Vector3.ZERO
	visual_mesh.visible = false
	collision_shape.set_deferred("disabled", true)
	
	if auto_respawn:
		await get_tree().create_timer(respawn_time).timeout
		respawn()

func respawn():
	print("Dummy Respawned")
	health_component.reset_health()
	visual_mesh.visible = true
	visual_mesh.scale = Vector3.ONE 
	collision_shape.set_deferred("disabled", false)
	_update_ui(health_component.current_health, health_component.max_health)
	
func _on_player_spawned():
	find_player()
	# Option B: Just update the reference, but wait for range check (Better)
	# logic_script.update_target_ref(new_player)

func _on_player_died():
	player_target = null
	# Return to idle state
