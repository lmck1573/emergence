@tool
extends Node2D
## 地图上的可点击切换点：绘制一个蓝色圆圈，左键点击后切换到 target_scene。
## 脚本带 @tool，蓝圈在编辑器中也会显示，可直接拖动本节点来摆放位置。

## 点击后要切换到的目标场景。
@export var target_scene: PackedScene
## 蓝色圆圈的半径（像素），同时作为点击判定半径。
@export var radius: float = 24.0

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.55, 1.0, 0.85))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.9), 2.0)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			if global_position.distance_to(get_global_mouse_position()) <= radius:
				_switch_scene()

func _switch_scene() -> void:
	if target_scene == null:
		push_warning("MapPoint 未配置 target_scene：%s" % name)
		return
	get_tree().change_scene_to_packed(target_scene)
