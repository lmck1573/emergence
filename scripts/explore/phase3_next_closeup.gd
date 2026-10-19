extends Control
## Third-phase close-up placeholder; its next destination awaits the script.

@onready var _leave_button: Button = $GameArea/LeaveButton
@onready var _save_button: Button = $GameArea/SaveButton
@onready var _heroine_hit_area: Area2D = $GameArea/HeroineHitArea
var _blocked: bool = false


func _ready() -> void:
	_set_leave_glyph()
	_save_button.hide()
	GameState.data["current_scene"] = "phase3_next_closeup"
	GameState.commit()
	EventBus.modal_changed.connect(_on_modal_changed)
	_leave_button.disabled = true
	_save_button.pressed.connect(_save)
	_heroine_hit_area.input_event.connect(_on_heroine_input_event)

func _set_leave_glyph() -> void:
	_leave_button.text = ""
	var label: Label = _leave_button.get_node_or_null("Label") as Label
	if label != null:
		label.text = "◀"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _on_modal_changed(blocked: bool) -> void:
	_blocked = blocked
	_save_button.disabled = blocked
	_heroine_hit_area.input_pickable = not blocked


func _on_heroine_input_event(_viewport: Viewport, event: InputEvent, _shape_index: int) -> void:
	if _blocked:
		return
	var pressed: bool = false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		pressed = mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed
	if not pressed:
		return
	get_viewport().set_input_as_handled()


func _save() -> void:
	if _blocked:
		return
	EventBus.audio_cue_requested.emit("sfx_save")
	EventBus.toast_requested.emit("已保存" if GameState.save() else "保存失败")
