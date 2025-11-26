class_name InputComponent
extends Node

# This component standardizes input. 
# Other scripts listen to THIS, not Input.is_action_pressed directy.
# This makes adding controller support or remapping keys easier later.

signal on_jump
signal on_attack_sword
signal on_attack_fireball
signal on_interact

var input_dir: Vector2 = Vector2.ZERO

func _process(_delta):
	# 1. Movement Input
	input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# 2. Action Signals
	if Input.is_action_just_pressed("jump"):
		on_jump.emit()
	
	if Input.is_action_just_pressed("attack_primary"): # Left Click
		on_attack_sword.emit()
		
	if Input.is_action_just_pressed("attack_secondary"): # Right Click/F
		on_attack_fireball.emit()

	if Input.is_action_just_pressed("interact"): # E key
		on_interact.emit()
