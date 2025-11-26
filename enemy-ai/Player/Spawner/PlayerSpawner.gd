#class_name PlayerSpawner
#extends Marker3D
#
#@export_group("Assets")
#@export var player_scene: PackedScene
#@export var hud_scene: PackedScene
#
## We keep track of the HUD so we can delete the old one when respawning
#var current_hud_instance: Node = null
#
#func _ready():
	## We defer the spawn to ensure the Main Scene is fully loaded first
	#call_deferred("_spawn_player_and_ui")
#
#func _spawn_player_and_ui():
	#if not player_scene:
		#push_error("PlayerSpawner: No Player Scene assigned!")
		#return
#
	## 1. Instantiate the Player
	#var player_instance = player_scene.instantiate()
	#
	## IMPORTANT: Force the name to "Player" so enemies find the specific node, 
	## not "Player2" or "@CharacterBody3D@..."
	#player_instance.name = "player"
	#
	## 2. Align Player with Spawner (Position and Rotation)
	#player_instance.global_transform = global_transform
	#
	## 3. Add Player to the Scene (Siblings with this spawner)
	#get_parent().add_child(player_instance)
	##SignalBus.player_spawned.emit(player_instance)
	#SignalBus.player_spawned.emit()
	#
	## --- NEW: Connect Death Signal ---
	## We listen for the signal we added to RootController earlier
	#if player_instance.has_signal("on_player_died"):
		#player_instance.on_player_died.connect(_start_respawn_sequence)
	#
	## 4. Instantiate and Connect UI
	#if hud_scene:
		## Cleanup: If there is an old HUD from the previous life, destroy it first
		#if current_hud_instance and is_instance_valid(current_hud_instance):
			#current_hud_instance.queue_free()
#
		#var hud_instance = hud_scene.instantiate()
		#current_hud_instance = hud_instance # Store reference for next time
		#
		## Add UI to the Scene (CanvasLayers ignore 3D position)
		#get_tree().current_scene.add_child(hud_instance)
		#
		## 5. THE MAGIC: Wire them together
		#if hud_instance.has_method("setup_ui"):
			#hud_instance.setup_ui(player_instance)
			#
	## REMOVED: queue_free() 
	## The Spawner must stay alive to handle the respawn later!
#
#func _start_respawn_sequence():
	#print("Player died. Respawning in 3 seconds...")
	#
	## Wait for 3 seconds (adjust this time if you want)
	#await get_tree().create_timer(3.0).timeout
	#
	## Optional Safety: Ensure the old player is definitely gone before spawning a new one
	## (In case the old one didn't delete itself yet)
	#var old_player = get_parent().get_node_or_null("player")
	#if old_player and is_instance_valid(old_player):
		#old_player.queue_free()
		## Wait one frame for the deletion to process
		#await get_tree().process_frame 
	#
	## Restart the cycle
	#_spawn_player_and_ui()
class_name PlayerSpawner
extends Marker3D

@export_group("Assets")
@export var player_scene: PackedScene
@export var hud_scene: PackedScene

# We keep track of the HUD so we can delete the old one when respawning
var current_hud_instance: Node = null

func _ready():
	# Listen for the UI button request
	SignalBus.respawn_requested.connect(_on_respawn_requested)
	
	# Initial Spawn
	call_deferred("_spawn_player_and_ui")

func _spawn_player_and_ui():
	if not player_scene:
		push_error("PlayerSpawner: No Player Scene assigned!")
		return
		
	# Add Player to the Scene
	# EMIT THIS WITH THE INSTANCE:

	# --- 1. Instantiate the Player ---
	var player_instance = player_scene.instantiate()
	
	# Force name so enemies find it
	player_instance.name = "player"
	
	# Align Player with Spawner
	player_instance.global_transform = global_transform
	
	# Add Player to the Scene
	get_parent().add_child(player_instance)
	#SignalBus.player_spawned.emit(player_instance)
	SignalBus.player_spawned.emit()
	
	
	# Notify system (Optional, if you use this signal)
	# SignalBus.player_spawned.emit()
	
	# --- 2. Instantiate and Connect UI ---
	if hud_scene:
		var hud_instance = hud_scene.instantiate()
		current_hud_instance = hud_instance 
		
		# Add UI to the Scene
		get_tree().current_scene.add_child(hud_instance)
		
		# THE MAGIC: Wire them together
		if hud_instance.has_method("setup_ui"):
			hud_instance.setup_ui(player_instance)

# This function is now triggered by the UI Button via SignalBus
func _on_respawn_requested():
	print("Respawn requested. Cleaning up...")
	
	# 1. Delete the Old HUD
	if current_hud_instance and is_instance_valid(current_hud_instance):
		current_hud_instance.queue_free()
		
	# 2. Delete the Old Player
	# We look for the sibling node named "player"
	var old_player = get_parent().get_node_or_null("player")
	if old_player and is_instance_valid(old_player):
		old_player.queue_free()
	
	# 3. Wait a frame for deletion to finish, then spawn anew
	await get_tree().process_frame 
	_spawn_player_and_ui()
