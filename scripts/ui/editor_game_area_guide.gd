@tool
extends ColorRect
## White alignment reference visible only when its scene is edited directly.

func _ready() -> void:
	visible = Engine.is_editor_hint() and get_tree().edited_scene_root == owner
