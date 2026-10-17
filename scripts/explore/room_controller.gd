extends Node2D
## Investigation navigation only; rewards are handled by the content system.
@onready var _return_button: Button = $GameArea/ReturnButton
var _active: String = ""
var _index: int = 0
var _steps: Array[Dictionary] = []
var _blocked: bool = false

func _ready() -> void:
	EventBus.modal_changed.connect(_lock)
	EventBus.investigation_next.connect(_next)
	EventBus.investigation_previous.connect(_previous)
	EventBus.fulltext_finished.connect(_closed)
	for node: Node in get_tree().get_nodes_in_group("interactive_object"):
		var object: InteractiveObject = node as InteractiveObject
		if object != null:
			object.clicked.connect(_clicked)
	# Existing scenes already connect the return button in the editor.
	if not _return_button.pressed.is_connected(_on_return_button_pressed):
		_return_button.pressed.connect(_on_return_button_pressed)

func _lock(blocked: bool) -> void:
	_blocked = blocked
	_return_button.disabled = blocked

func _clicked(id: String, _dialogue: String) -> void:
	if _blocked:
		return
	_active = id
	_steps.assign(ContentDB.get_object(id).get("steps", []))
	if _steps.is_empty():
		_active = ""
		return
	EventBus.object_clicked.emit(id)
	var completed: Array[String] = GameState.get_object_steps(id)
	_index = maxi(0, mini(completed.size() - 1, _steps.size() - 1))
	if ContentDB.get_object(id).get("repeat_text_policy") == "first_step" and completed.size() == _steps.size():
		_index = 0
	_show()

func _show() -> void:
	var next_label: String = ""
	if _index + 1 < _steps.size():
		next_label = str(_steps[_index + 1].get("operation_label", ""))
	EventBus.fulltext_requested.emit(str(_steps[_index]["text_ref"]), next_label, _index > 0)

func _complete() -> void:
	var step_id: String = str(_steps[_index]["step_id"])
	EventBus.object_step_completed.emit(_active, step_id)
	var completed: Array[String] = GameState.get_object_steps(_active)
	if completed.size() == _steps.size():
		EventBus.object_investigated.emit(_active)

func _next() -> void:
	if _active.is_empty() or _index + 1 >= _steps.size():
		return
	_complete()
	_index += 1
	_show()

func _previous() -> void:
	if _active.is_empty() or _index == 0:
		return
	_index -= 1
	_show()

func _closed(text_id: String) -> void:
	if _active.is_empty():
		return
	if text_id == str(_steps[_index]["text_ref"]):
		_complete()
		if _active == "livingroom_document":
			EventBus.command_requested.emit("black_flash")
	_active = ""

func _on_return_button_pressed() -> void:
	if _blocked:
		return
	GameState.data["current_scene"] = "house_overview"
	GameState.commit()
	get_tree().change_scene_to_file("res://scenes/explore/house_overview.tscn")
