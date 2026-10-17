extends Control
## Start screen with a single entry into the AI interaction scene.

@onready var _start_button: Button = $StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ai_interface.tscn")
