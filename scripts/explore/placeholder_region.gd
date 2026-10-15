extends Node2D
## 占位区域场景：显示区域名，并提供「返回地图」按钮。
## 后续由 SceneManager 统一接管场景切换后，这里改为走对外接口。

const MAP_SCENE_PATH: String = "res://scenes/explore/house_overview.tscn"

func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file(MAP_SCENE_PATH)
