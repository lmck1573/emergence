extends Node2D
## Investigation navigation only; rewards are handled by the content system.
@onready var _return_button: Button = $GameArea/ReturnButton
@onready var _name_label: Label = $GameArea/NameBar/NameLabel
var _active: String = ""
var _index: int = 0
var _steps: Array[Dictionary] = []
var _blocked: bool = false
var _computer_screen_open: bool = false
var _computer_fallback: Texture2D
var _computer_changing: bool = false

func _ready() -> void:
	_computer_screen_open = scene_file_path in ["res://scenes/explore/computer_locked.tscn", "res://scenes/explore/computer_unlocked.tscn"]
	_set_return_glyph()
	if scene_file_path in ["res://scenes/explore/computer_desk.tscn", "res://scenes/explore/computer_locked.tscn", "res://scenes/explore/computer_unlocked.tscn"]:
		_computer_fallback = ($GameArea/RoomBackdrop as TextureRect).texture
	EventBus.state_changed.connect(refresh_computer_picture, CONNECT_DEFERRED)
	refresh_computer_picture.call_deferred()
	EventBus.modal_changed.connect(_lock)
	EventBus.investigation_next.connect(_next)
	EventBus.investigation_previous.connect(_previous)
	EventBus.fulltext_finished.connect(_closed)
	if GameState.data["current_scene"] == "wife_room" and not bool(GameState.data["flags"].get("wife_room_entered", false)):
		EventBus.fulltext_requested.emit("ft_wiferoom_entry", "", false)
		var entry_text: String = await EventBus.fulltext_finished
		if entry_text == "ft_wiferoom_entry":
			GameState.data["flags"]["wife_room_entered"] = true
			GameState.commit()
	for node: Node in get_tree().get_nodes_in_group("interactive_object"):
		var object: InteractiveObject = node as InteractiveObject
		if object != null:
			object.clicked.connect(_clicked)
			object.hovered.connect(_on_object_hovered)
			object.unhovered.connect(_on_object_unhovered)
	# Existing scenes already connect the return button in the editor.
	if not _return_button.pressed.is_connected(_on_return_button_pressed):
		_return_button.pressed.connect(_on_return_button_pressed)

func _set_return_glyph() -> void:
	_return_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var label: Label = _return_button.get_node_or_null("Label") as Label
	if label != null:
		_return_button.text = ""
		label.text = "◀"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		_return_button.text = "◀"

func _lock(blocked: bool) -> void:
	_blocked = blocked
	_return_button.disabled = blocked
	if blocked:
		_name_label.text = ""
	elif _computer_screen_open:
		refresh_computer_picture.call_deferred()

func _on_object_hovered(display_name: String) -> void:
	if not _blocked:
		_name_label.text = display_name

func _on_object_unhovered() -> void:
	_name_label.text = ""

func _clicked(id: String, _dialogue: String) -> void:
	if _blocked:
		return
	_name_label.text = ""
	if id == "wiferoom_computer":
		GameState.data["current_scene"] = "computer_desk"
		GameState.commit()
		get_tree().change_scene_to_file("res://scenes/explore/computer_desk.tscn")
		return
	if id == "computer_locked_entry":
		var password_state: Dictionary = GameState.data.get("puzzles", {}).get("puzzle_diary_password", {})
		if not bool(password_state.get("unlocked", false)):
			EventBus.toast_requested.emit("密码提示尚未解锁")
			return

		EventBus.puzzle_requested.emit("puzzle_diary_password")
		return
	if id == "computer_notebooks" and GameState.is_event_completed("event_diary_password_hint"):
		var hint_seen: bool = bool(GameState.data["flags"].get("computer_notebooks_hint_seen", false))
		if not hint_seen:
			EventBus.fulltext_requested.emit("ft_computer_notebooks_hint", "", false)
			var finished_text_id: String = await EventBus.fulltext_finished
			if finished_text_id != "ft_computer_notebooks_hint":
				return
			GameState.data["flags"]["computer_notebooks_hint_seen"] = true
			GameState.commit()
			await get_tree().process_frame
		EventBus.diary_viewer_requested.emit()
		return
	if id == "computer_power_button":
		EventBus.command_requested.emit("black_flash")
		await EventBus.command_finished
		if not GameState.get_object_steps(id).is_empty():
			_open_computer_screen()
			return
	if id in ["computer_folder_games", "computer_folder_social", "computer_folder_bills"]:
		var folder_password_state: Dictionary = GameState.data.get("puzzles", {}).get("puzzle_diary_password", {})
		if not bool(folder_password_state.get("completed", false)):
			EventBus.toast_requested.emit("电脑尚未解锁")
			return
	_active = id
	_steps.assign(ContentDB.get_object(id).get("steps", []))
	if _steps.is_empty():
		_active = ""
		return
	EventBus.object_clicked.emit(id)
	var completed: Array[String] = GameState.get_object_steps(id)
	_index = mini(completed.size(), _steps.size() - 1)
	if id == "kitchen_couple_bowls":
		_index = 0
	if ContentDB.get_object(id).get("repeat_text_policy") == "first_step" and completed.size() == _steps.size():
		_index = 0
	_show()

func _show() -> void:
	var next_label: String = ""
	if _active != "kitchen_couple_bowls" and _index + 1 < _steps.size():
		next_label = str(_steps[_index + 1].get("operation_label", ""))
	EventBus.fulltext_requested.emit(str(_steps[_index]["text_ref"]), next_label, _index > 0)

func _complete() -> void:
	if _active == "kitchen_couple_bowls":
		EventBus.object_step_completed.emit(_active, "look")
		EventBus.object_step_completed.emit(_active, "flip")
		EventBus.object_investigated.emit(_active)
		return
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
	var opened_computer: bool = _active == "computer_power_button"
	_active = ""
	if opened_computer:
		_open_computer_screen.call_deferred()

func _on_return_button_pressed() -> void:
	if _blocked:
		return
	if _computer_screen_open:
		get_tree().change_scene_to_file("res://scenes/explore/computer_desk.tscn")
		return
	var current_id: String = str(GameState.data.get("current_scene", "house_overview"))
	var region: Dictionary = ContentDB.get_region(current_id)
	var parent_id: String = str(region.get("parent", "house_overview"))
	var parent_region: Dictionary = ContentDB.get_region(parent_id)
	var scene_path: String = str(parent_region.get("scene_path", "res://scenes/explore/house_overview.tscn"))
	GameState.data["current_scene"] = parent_id
	GameState.commit()
	get_tree().change_scene_to_file(scene_path)

func refresh_computer_picture() -> void:
	if not is_inside_tree() or _computer_changing:
		return
	if scene_file_path not in ["res://scenes/explore/computer_desk.tscn", "res://scenes/explore/computer_locked.tscn", "res://scenes/explore/computer_unlocked.tscn"]:
		return
	var catalog: GDScript = preload("res://scripts/ui/game_picture_catalog.gd")
	var puzzle: Dictionary = GameState.data.get("puzzles", {}).get("puzzle_diary_password", {})
	var unlocked: bool = bool(puzzle.get("completed", false))
	if scene_file_path.ends_with("computer_locked.tscn") and unlocked and not _blocked:
		_open_computer_screen()
		return
	var image: Texture2D = catalog.texture("computer_unlocked" if unlocked else "computer_locked") if _computer_screen_open else catalog.room("computer_desk")
	if image == null:
		image = catalog.room("computer_desk")
	if image == null:
		image = _computer_fallback
	catalog.apply_picture(self, "GameArea/RoomBackdrop", image)
	for path: String in ["GameArea/MonitorFrame", "GameArea/MonitorScreen", "GameArea/ScreenTitle", "GameArea/Title"]:
		var decoration: CanvasItem = get_node_or_null(NodePath(path)) as CanvasItem
		if decoration != null:
			decoration.hide()
	for node: Node in get_tree().get_nodes_in_group("interactive_object"):
		var point: InteractiveObject = node as InteractiveObject
		if point == null or not is_ancestor_of(point):
			continue
		match point.object_id:
			"computer_power_button":
				point.visible = not _computer_screen_open
			"computer_locked_entry":
				point.visible = _computer_screen_open and not unlocked
			"computer_folder_games", "computer_folder_social", "computer_folder_bills":
				point.visible = _computer_screen_open and unlocked
			_:
				pass
		point.input_pickable = point.visible and not _blocked

func _open_computer_screen() -> void:
	if not is_inside_tree() or _computer_changing:
		return
	_computer_changing = true
	var puzzle: Dictionary = GameState.data.get("puzzles", {}).get("puzzle_diary_password", {})
	var destination: String = "computer_unlocked" if bool(puzzle.get("completed", false)) else "computer_locked"
	get_tree().call_deferred("change_scene_to_file", "res://scenes/explore/%s.tscn" % destination)
