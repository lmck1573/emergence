@tool
extends Node2D
## Editor-positioned map destination.
@export var target_scene: PackedScene
@export var region_id: String = ""
@export var radius: float = 24.0
var _blocked: bool = false
var _hovering: bool = false

func _ready() -> void:
	if not Engine.is_editor_hint():
		EventBus.modal_changed.connect(_lock)

func _lock(blocked: bool) -> void:
	_blocked = blocked
	if blocked:
		_hovering = false

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var inside: bool = not _blocked and is_visible_in_tree() and global_position.distance_to(get_global_mouse_position()) <= radius
	if inside == _hovering:
		return
	_hovering = inside
	if inside:
		EventBus.audio_cue_requested.emit("sfx_hover")

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.55, 1.0, 0.85))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color.WHITE, 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _blocked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if global_position.distance_to(get_global_mouse_position()) <= radius:
			get_viewport().set_input_as_handled()
			EventBus.audio_cue_requested.emit("sfx_click")
			if not region_id.is_empty() and not GameState.is_region_unlocked(region_id):
				EventBus.toast_requested.emit("暂时无法进入")
				return
			if target_scene != null:
				GameState.data["current_scene"] = region_id
				GameState.commit()
				get_tree().change_scene_to_packed(target_scene)
