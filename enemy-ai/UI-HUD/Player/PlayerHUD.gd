#extends CanvasLayer
#
#@onready var hp_bar = $Control/MarginContainer/VBoxContainer/HPBar
#@onready var speed_label = $Control/MarginContainer/VBoxContainer/SpeedLabel
#@onready var dmg_label = $Control/MarginContainer/VBoxContainer/DamageLabel
#
## We inject the dependency externally.
#func setup_ui(player: PlayerController):
	## 1. Connect Health (Assuming HealthComponent has on_health_changed(current, max))
	#if player.health:
		#player.health.on_health_changed.connect(update_health)
		## Initialize
		#update_health(player.health.current_health, player.health.max_health)
	#
	## 2. Connect Movement Speed
	#if player.movement:
		#player.movement.on_speed_changed.connect(update_speed)
		## Initialize manual check
		#update_speed(player.movement.speed)
#
	## 3. Connect Combat Stats
	#if player.combat:
		#player.combat.on_damage_multiplier_changed.connect(update_dmg)
		#update_dmg(player.combat.damage_multiplier)
#
#func update_health(current, max_hp):
	#hp_bar.max_value = max_hp
	#hp_bar.value = current
#
#func update_speed(new_speed):
	#speed_label.text = "Speed: %.1f" % new_speed
#
#func update_dmg(new_mult):
	#dmg_label.text = "Dmg Mult: x%.1f" % new_mult
extends CanvasLayer

# --- NODES ---
# IMPORTANT: Ensure your root Control node is renamed to "GameplayContainer"
@onready var gameplay_container = $GameplayContainer 

@onready var hp_bar = $GameplayContainer/MarginContainer/VBoxContainer/HPBar
@onready var speed_label = $GameplayContainer/MarginContainer/VBoxContainer/SpeedLabel
@onready var dmg_label = $GameplayContainer/MarginContainer/VBoxContainer/DamageLabel

# Death Screen Nodes
@onready var death_overlay = $DeathOverlay
@onready var respawn_btn = $DeathOverlay/CenterContainer/VBoxContainer/RespawnButton
@onready var anim_player = $AnimationPlayer

func _ready():
	# 1. Connect the respawn button locally
	respawn_btn.pressed.connect(_on_respawn_pressed)
	
	# 2. Listen for the GLOBAL death signal
	SignalBus.player_died.connect(_on_player_died)
	
	# 3. PLAY SPAWN ANIMATION
	# Since this script is brand new (just spawned), we start with the overlay 
	# visible (black) and fade it out to reveal the game.
	death_overlay.visible = true
	death_overlay.modulate.a = 1.0
	gameplay_container.visible = true
	
	# Ensure this animation exists: Fades DeathOverlay Alpha from 1 -> 0
	anim_player.play("fade_in_respawn")

func setup_ui(player: PlayerController):
	# Dependency Injection logic (Same as before)
	if player.health:
		player.health.on_health_changed.connect(update_health)
		update_health(player.health.current_health, player.health.max_health)
	
	if player.movement:
		player.movement.on_speed_changed.connect(update_speed)
		update_speed(player.movement.speed)

	if player.combat:
		player.combat.on_damage_multiplier_changed.connect(update_dmg)
		update_dmg(player.combat.damage_multiplier)

# --- UPDATERS ---
func update_health(current, max_hp):
	hp_bar.max_value = max_hp
	hp_bar.value = current

func update_speed(new_speed):
	speed_label.text = "Speed: %.1f" % new_speed

func update_dmg(new_mult):
	dmg_label.text = "Dmg Mult: x%.1f" % new_mult

# --- DEATH LOGIC ---

func _on_player_died():
	# Unlock mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Ensure overlay is active
	death_overlay.visible = true
	
	# Play animation: Fade Alpha 0 -> 1, Hide GameplayContainer
	anim_player.play("fade_to_death")

func _on_respawn_pressed():
	# Prevent double clicks
	respawn_btn.disabled = true
	
	# Emit signal. The PlayerSpawner is listening for this!
	SignalBus.respawn_requested.emit()
	
	# We do NOT queue_free() here. 
	# The Spawner will delete us when it receives the signal.
