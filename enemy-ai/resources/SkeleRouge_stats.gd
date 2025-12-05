# res://Resources/skele_mage_stats.gd
extends EnemyStats
class_name SkeleMageStats

@export_group("Magic Settings")
# The fireball/magic bolt object to spawn
@export var projectile_scene: PackedScene 
@export var projectile_speed: float = 10.0
@export var cast_color: Color = Color.PURPLE # Optional: for particle effects
