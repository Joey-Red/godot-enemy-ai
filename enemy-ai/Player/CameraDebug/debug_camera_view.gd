extends SubViewportContainer

# Key to toggle the view (Default is P)
@export var toggle_key: Key = KEY_P

@onready var sub_viewport = $SubViewport

func _ready():
	# 1. Share the World so we see the Player
	sub_viewport.world_3d = get_tree().root.get_viewport().world_3d
	
	# 2. Find the Camera inside the SubViewport
	# We look for a child node of type Camera3D
	var cam = _find_camera(sub_viewport)
	
	if cam:
		# CRITICAL: Tell the SubViewport to use THIS camera, not the Player's
		cam.current = true
		
		# CRITICAL: Detach from UI parent so we can move it freely in 3D space
		cam.top_level = true
	else:
		push_warning("DebugView: No Camera3D found inside SubViewport!")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == toggle_key:
		visible = not visible

# Helper to find the camera even if you renamed it
func _find_camera(parent: Node) -> Camera3D:
	for child in parent.get_children():
		if child is Camera3D:
			return child
	return null
