class_name SpawnDefinition
extends Resource

@export_group("Spawn Settings")
@export var enemy_scene: PackedScene
@export_range(1, 100) var spawn_weight: int = 10

@export_group("Optional Overrides")
# If set, this will overwrite the enemy's 'stats' variable before spawning.
# Useful if you want to use the same "DummyEnemy.tscn" but different Stats Resources.
@export var stats_override: EnemyStats
