@tool
extends Node2D
class_name InteractiveObject
## Editor-positioned placeholder; interaction is blocked by all modal UI.
## Mouse entered this object's click area.
signal hovered(display_name: String)
## Mouse left this object's click area.
signal unhovered()
## Clicked an available investigation point.
signal clicked(object_id: String, dialogue_id: String)
@export var object_id: String = ""
@export var dialogue_id: String = ""
@export var radius: float = 30.0
var _blocked: bool = false
var _rect: Rect2 = Rect2(-50, -50, 100, 100)
var _hovering: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("interactive_object")
	EventBus.modal_changed.connect(_lock)
	EventBus.state_changed.connect(_refresh)
	var area: Dictionary = ContentDB.get_object(object_id).get("click_area", {})
	_rect = Rect2(-float(area.get("w", 100)) / 2.0, -float(area.get("h", 100)) / 2.0, float(area.get("w", 100)), float(area.get("h", 100)))
	_refresh()

func _lock(blocked: bool) -> void:
	_blocked = blocked
	if blocked and _hovering:
		_hovering = false
		unhovered.emit()

func _refresh() -> void:
	if object_id == "livingroom_document":
		visible = GameState.get_object_steps(object_id).is_empty()
	if object_id == "kitchen_fridge" and not GameState.get_object_steps(object_id).is_empty():
		modulate = Color(1.25, 1.25, 1.25)
	queue_redraw()

func _draw() -> void:
	draw_rect(_rect, Color(0.35, 0.8, 0.45, 0.65))
	draw_rect(_rect, Color.WHITE, false, 2.0)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var inside: bool = not _blocked and is_visible_in_tree() and _rect.has_point(get_local_mouse_position())
	if inside == _hovering:
		return
	_hovering = inside
	if inside:
		hovered.emit(str(ContentDB.get_object(object_id).get("display_name", "")))
		EventBus.audio_cue_requested.emit("sfx_hover")
	else:
		unhovered.emit()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or _blocked or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _rect.has_point(get_local_mouse_position()):
			get_viewport().set_input_as_handled()
			var feedback: String = str(ContentDB.get_object(object_id).get("click_feedback", "sfx_click"))
			EventBus.audio_cue_requested.emit("sfx_click" if feedback == "sfx_none" else feedback)
			clicked.emit(object_id, dialogue_id)
