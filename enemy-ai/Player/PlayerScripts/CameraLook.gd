class_name CameraComponent
extends Node3D

# Assign the "Player" node to this in the Inspector
@export var body_to_rotate: CharacterBody3D

@export_group("Settings")
@export var sensitivity: float = 0.003
@export var max_look_angle: float = 40.0  # Max looking UP (Degrees)
@export var min_look_angle: float = -60.0 # Max looking DOWN (Degrees)

# --- NEW SECTION: SKELETON CONTROL ---
@export_group("Visuals")
@export var skeleton: Skeleton3D # Drag your Skeleton3D here
@export var spine_bone_name: String = "Spine" # Name of the bone to bend
var _spine_bone_idx: int = -1
# -------------------------------------

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	process_priority = 1 # Important: Runs AFTER animation to override the spine
	
	if skeleton:
		_spine_bone_idx = skeleton.find_bone(spine_bone_name)
		if _spine_bone_idx == -1:
			print("Warning: Could not find bone named '" + spine_bone_name + "'")

func _input(event):
	# Toggle Mouse Mode with Middle Click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			toggle_mouse_mode()

	# Handle Rotation
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# 1. Rotate the BODY (Player) left/right around the Y axis
		if body_to_rotate:
			body_to_rotate.rotate_y(-event.relative.x * sensitivity)
		
		# 2. Rotate the HEAD (Self) up/down around the X axis
		rotate_x(-event.relative.y * sensitivity)
		
		# 3. FORCE THE CLAMP
		rotation_degrees.x = clamp(rotation_degrees.x, min_look_angle, max_look_angle)

func _process(_delta):
	# This updates every frame to visually bend the character's spine
	if skeleton and _spine_bone_idx != -1:
		# THE FIX: Added a negative sign (-) to rotation.x
		# This inverts the bone rotation to match the camera direction
		var spine_rotation = Quaternion(Vector3.RIGHT, -rotation.x)
		
		# Apply this rotation to the spine bone
		skeleton.set_bone_pose_rotation(_spine_bone_idx, spine_rotation)

func toggle_mouse_mode():
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
