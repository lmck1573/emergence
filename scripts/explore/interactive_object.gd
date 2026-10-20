@tool
extends Area2D
class_name InteractiveObject
## Editor-adjustable hit area; interaction is blocked by all modal UI.
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
var _hovering: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("interactive_object")
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	EventBus.modal_changed.connect(_lock)
	EventBus.state_changed.connect(_refresh)
	_refresh()

func _lock(blocked: bool) -> void:
	_blocked = blocked
	if blocked and _hovering:
		_hovering = false
		unhovered.emit()
	input_pickable = not blocked and is_visible_in_tree()

func _refresh() -> void:
	if object_id == "livingroom_document":
		visible = GameState.get_object_steps(object_id).is_empty()
	if object_id == "kitchen_fridge" and not GameState.get_object_steps(object_id).is_empty():
		modulate = Color(1.25, 1.25, 1.25)
	var password_state: Dictionary = GameState.data.get("puzzles", {}).get("puzzle_diary_password", {})
	if object_id == "computer_power_button":
		visible = true
	elif object_id == "computer_locked_entry":
		visible = not bool(password_state.get("completed", false))
	elif object_id in ["computer_folder_games", "computer_folder_social", "computer_folder_bills"]:
		visible = bool(password_state.get("completed", false))
	input_pickable = not _blocked and is_visible_in_tree()


func _on_mouse_entered() -> void:
	if _blocked or not is_visible_in_tree() or _hovering:
		return
	_hovering = true
	hovered.emit(str(ContentDB.get_object(object_id).get("display_name", "")))
	EventBus.audio_cue_requested.emit("sfx_hover")


func _on_mouse_exited() -> void:
	if not _hovering:
		return
	_hovering = false
	unhovered.emit()


func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_index: int) -> void:
	if _blocked or not is_visible_in_tree():
		return
	var pressed: bool = false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		pressed = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		pressed = touch_event.pressed and _contains_screen_position(touch_event.position)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	var feedback: String = str(ContentDB.get_object(object_id).get("click_feedback", "sfx_click"))
	EventBus.audio_cue_requested.emit("sfx_click" if feedback == "sfx_none" else feedback)
	clicked.emit(object_id, dialogue_id)


func contains_screen_position(screen_position: Vector2) -> bool:
	var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * screen_position
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.disabled or shape_node.shape == null:
		return false
	var shape_position: Vector2 = shape_node.transform.affine_inverse() * local_position
	if shape_node.shape is RectangleShape2D:
		var rectangle: RectangleShape2D = shape_node.shape as RectangleShape2D
		return Rect2(-rectangle.size * 0.5, rectangle.size).has_point(shape_position)
	if shape_node.shape is CircleShape2D:
		var circle: CircleShape2D = shape_node.shape as CircleShape2D
		return shape_position.length() <= circle.radius
	return false


func _contains_screen_position(screen_position: Vector2) -> bool:
	return contains_screen_position(screen_position)
