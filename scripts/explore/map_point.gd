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
		EventBus.region_unlocked.connect(_on_region_unlocked)
		if not region_id.is_empty():
			visible = _is_available()

func _on_region_unlocked(unlocked_region_id: String) -> void:
	if unlocked_region_id == region_id:
		_refresh_visibility.call_deferred()

func _refresh_visibility() -> void:
	visible = _is_available()

func _is_available() -> bool:
	if GameState.get_current_phase() == 2:
		if region_id == "ai_interface":
			return true
		if region_id == "wife_room":
			return GameState.is_event_completed("event_unlock_wife_room")
		return false
	return GameState.is_region_unlocked(region_id)

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
	var pressed: bool = false
	var local_position: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		pressed = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
		local_position = to_local(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		pressed = touch_event.pressed
		local_position = get_global_transform_with_canvas().affine_inverse() * touch_event.position
	if not pressed or local_position.length() > radius:
		return
	get_viewport().set_input_as_handled()
	EventBus.audio_cue_requested.emit("sfx_click")
	if not region_id.is_empty() and not _is_available():
		EventBus.toast_requested.emit("暂时无法进入")
		return
	if target_scene != null:
		GameState.data["current_scene"] = region_id
		GameState.commit()
		if region_id == "ai_interface" and GameState.get_current_phase() == 2:
			get_tree().change_scene_to_file("res://scenes/ui/ai_interface_phase2.tscn")
		else:
			get_tree().change_scene_to_packed(target_scene)
