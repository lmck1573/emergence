extends Button
## Shared manual save control, positioned beside the audio control.

func _ready() -> void:
	add_to_group("act3_ending_ui")
	text = "存档"
	position = Vector2(280.0, 60.0)
	size = Vector2(50.0, 50.0)
	custom_minimum_size = size
	z_index = 100
	modulate = Color(0.45, 0.7, 1.0, 1.0)
	add_theme_font_size_override("font_size", 14)
	pressed.connect(_save)

func _save() -> void:
	EventBus.audio_cue_requested.emit("sfx_save")
	EventBus.toast_requested.emit("已保存" if GameState.save() else "保存失败")
