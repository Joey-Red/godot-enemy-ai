class_name InteractionComponent
extends RayCast3D

# Attach this script to a RayCast3D node inside the Camera/Head.
# Ensure the RayCast3D 'Enabled' property is ON.
# Set 'Target Position' Z to -2 or -3 (forward in Godot is negative Z).

@export var input: InputComponent

func _ready():
	input.on_interact.connect(try_interact)

func try_interact():
	if is_colliding():
		var object = get_collider()
		
		# We check if the object has a method called "interact"
		if object.has_method("interact"):
			object.interact()
		else:
			print("Object found (" + object.name + ") but it is not interactable.")
