extends Control
## Holds the silent drawer close-up before the true ending screen.


func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/ending_silent_truth.tscn")
