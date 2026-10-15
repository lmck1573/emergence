@tool
extends Node2D
class_name InteractiveObject
## 可交互物体：绘制圆形占位；悬停上报名称，点击上报 object_id 与 dialogue_id。
## 显示名称通过 object_id 从 ContentDB 读取；grants 由场景控制器处理。

signal hovered(display_name: String)
signal unhovered
signal clicked(object_id: String, dialogue_id: String)

@export var object_id: String = ""
@export var dialogue_id: String = ""
@export var radius: float = 30.0

var _display_name: String = ""
var _is_hovered: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("interactive_object")
	_display_name = ContentDB.get_object_display_name(object_id)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.35, 0.8, 0.45, 0.65))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.9), 2.0)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var inside: bool = global_position.distance_to(get_global_mouse_position()) <= radius
	if inside and not _is_hovered:
		_is_hovered = true
		hovered.emit(_display_name)
	elif not inside and _is_hovered:
		_is_hovered = false
		unhovered.emit()


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if global_position.distance_to(get_global_mouse_position()) <= radius:
				# 点击后重置悬停状态，对话框关闭后鼠标仍悬停时能重新上报名称
				_is_hovered = false
				clicked.emit(object_id, dialogue_id)
