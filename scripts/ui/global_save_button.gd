extends TextureButton
## Shared manual save control, positioned in the StoryUI scene.

func _ready() -> void:
	add_to_group("act3_ending_ui")
	pressed.connect(_save)

func _save() -> void:
	if not is_visible_in_tree() or disabled:
		return
	EventBus.audio_cue_requested.emit("sfx_save")
	EventBus.toast_requested.emit("已保存" if GameState.save() else "保存失败")
