extends Sprite3D

@onready var progress_bar = $SubViewport/ProgressBar

func update_bar(current_hp, max_hp):
	progress_bar.max_value = max_hp
	progress_bar.value = current_hp
	
	# Optional: Hide if full health or dead
	visible = current_hp < max_hp and current_hp > 0
