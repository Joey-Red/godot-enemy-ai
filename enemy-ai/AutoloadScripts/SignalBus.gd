# SignalBus.gd
extends Node

# Emitted when the player is instantiated/spawned
# Useful for: Enemies finding the player, Camera locking on
signal player_spawned(player_node)

# Emitted when the player dies (HP <= 0)
# Useful for: triggering the Death Screen, stopping music, disabling inputs
signal player_died

# Emitted when the UI "Respawn" button is clicked
# Useful for: The PlayerSpawner knowing it is time to reset the level
signal respawn_requested
