class_name CombatComponent
extends Node

signal on_damage_multiplier_changed(new_mult: float)
@export var damage_multiplier: float = 1.0:
	set(value):
		damage_multiplier = value
		on_damage_multiplier_changed.emit(damage_multiplier)

@export_group("References")
@export var animation_tree: AnimationTree
@export var input: InputComponent
@export var projectile_spawn_point: Node3D
@export var projectile_scene: PackedScene 
@export var camera: Camera3D 

@onready var sword_scene = $"../../RootNode/CharacterArmature/Skeleton3D/WeaponSocket_Normal/Sword"

var can_fireball: bool = true 
@export var fireball_cooldown: float = 0.6 

func _ready():
	input.on_attack_sword.connect(perform_sword_attack)
	input.on_attack_fireball.connect(perform_fireball)
	
	# Emit initial value for UI initialization
	# We defer it slightly to ensure UI is ready if they load same frame
	call_deferred("emit_signal", "on_damage_multiplier_changed", damage_multiplier)
func perform_sword_attack():
	if not sword_scene.currently_attacking:
		animation_tree.set("parameters/AttackType/transition_request", "state_0")
		animation_tree.set("parameters/AttackShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		sword_scene.attack()
		
func perform_fireball():
	if not can_fireball:
		return
		
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

	await get_tree().create_timer(fireball_cooldown).timeout
	can_fireball = true
