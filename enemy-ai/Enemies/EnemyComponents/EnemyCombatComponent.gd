class_name EnemyCombatComponent
extends Node

# Signal to tell the main script (or animation player) to play the attack animation
signal on_attack_performed

@export_group("Stats")
@export var damage: int = 10
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5

@export_group("References")
@export var actor: Node3D # The Enemy Root

var target: Node3D
var _can_attack: bool = true
var _timer: Timer

func _ready():
	# Create cooldown timer via code
	_timer = Timer.new()
	_timer.wait_time = attack_cooldown
	_timer.one_shot = true
	_timer.timeout.connect(_on_cooldown_finished)
	add_child(_timer)


func set_target(new_target: Node3D):
	target = new_target

func _on_cooldown_finished():
	_can_attack = true

func try_attack():
	# 1. Basic Validation
	if not _can_attack or not target or not is_instance_valid(target):
		return

	# 2. Check Distance
	var distance = actor.global_position.distance_to(target.global_position)
	
	# 3. Perform Attack if in range
	#print('Distance: ',distance, ' Attack Range: ', attack_range)
	if distance <= attack_range:
		_perform_attack()

func _perform_attack():
	_can_attack = false
	_timer.start()
	
	# Emit signal so DummyEnemy can play animation/sound
	on_attack_performed.emit()
	
	
	# 4. Deal Damage to Target
	# We check if the target (Player) has a 'take_damage' method
	if target.has_method("take_damage"):
		target.take_damage(damage)
		
		
