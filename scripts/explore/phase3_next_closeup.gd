extends Control
## Third-phase close-up placeholder; its next destination awaits the script.

@onready var _leave_button: Button = $GameArea/LeaveButton
@onready var _save_button: Button = $GameArea/SaveButton
@onready var _heroine_hit_area: Area2D = $GameArea/HeroineHitArea
@onready var _heroine_collision_shape: CollisionShape2D = $GameArea/HeroineHitArea/CollisionShape2D
var _blocked: bool = false


func _ready() -> void:
	_leave_button.hide()
	_save_button.hide()
	GameState.data["current_scene"] = "phase3_next_closeup"
	GameState.commit()
	EventBus.modal_changed.connect(_on_modal_changed)
	_save_button.pressed.connect(_save)
	_heroine_hit_area.input_event.connect(_on_heroine_input_event)

func _on_modal_changed(blocked: bool) -> void:
	_blocked = blocked
	_save_button.disabled = blocked
	_heroine_hit_area.input_pickable = not blocked


func _on_heroine_input_event(_viewport: Viewport, event: InputEvent, _shape_index: int) -> void:
	if _blocked:
		return
	var pressed: bool = false
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		pressed = touch_event.pressed and _contains_heroine_touch(touch_event.position)
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		pressed = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	if not pressed:
		return
	get_viewport().set_input_as_handled()


func _contains_heroine_touch(screen_position: Vector2) -> bool:
	var local_position: Vector2 = _heroine_hit_area.get_global_transform_with_canvas().affine_inverse() * screen_position
	if _heroine_collision_shape.disabled or _heroine_collision_shape.shape == null:
		return false
	var shape_position: Vector2 = _heroine_collision_shape.transform.affine_inverse() * local_position
	if _heroine_collision_shape.shape is RectangleShape2D:
		var rectangle: RectangleShape2D = _heroine_collision_shape.shape as RectangleShape2D
		return Rect2(-rectangle.size * 0.5, rectangle.size).has_point(shape_position)
	return false


func _save() -> void:
	if _blocked:
		return
	EventBus.audio_cue_requested.emit("sfx_save")
	EventBus.toast_requested.emit("已保存" if GameState.save() else "保存失败")
