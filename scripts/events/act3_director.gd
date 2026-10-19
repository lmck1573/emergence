extends Node
## Executes the authored act-three routes; each command is a resumable save point.
const ViewScript: GDScript = preload("res://scripts/ui/act3_view.gd")
var cg_textures: Dictionary = {}
var _view: Act3View
var _data: Dictionary
var _route: String = ""
var _cursor: int = 0
var _dialogue_done: String = ""
var _command_done: String = ""
var _puzzle_done: String = ""

func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/act3_flow.json")) as Dictionary
	_view = ViewScript.new()
	add_child(_view)
	EventBus.dialogue_finished.connect(func(id: String) -> void: _dialogue_done = id)
	EventBus.command_finished.connect(func(id: String) -> void: _command_done = id)
	EventBus.puzzle_submitted.connect(_puzzle_submitted)
	_route = str(GameState.data["flags"].get("act3_route", "zero" if GameState.get_truth() == 0 else "positive"))
	_cursor = int(GameState.data["flags"].get("act3_cursor", 0))
	_restore_image()
	_run.call_deferred()

func _restore_image() -> void:
	if _route in ["refuse", "alone"]:
		_image({"action": "room", "id": "客厅"})
	var route: Array = _data["routes"][_route]
	for index: int in range(mini(_cursor, route.size())):
		var step: Dictionary = route[index]
		if str(step["action"]) in ["room", "cg", "black"]:
			_image(step)

func _checkpoint() -> void:
	GameState.data["current_scene"] = "phase3_kitchen"
	GameState.data["flags"]["act3_route"] = _route
	GameState.data["flags"]["act3_cursor"] = _cursor
	GameState.commit()

func _run() -> void:
	while is_inside_tree():
		var steps: Array = _data["routes"][_route]
		if _cursor >= steps.size(): return
		_checkpoint()
		var step: Dictionary = steps[_cursor]
		var action: String = str(step["action"])
		_view.clear_controls()
		match action:
			"room", "cg", "black":
				await _command("black_flash")
				if action == "room" and str(step.get("id", "")) == "客厅":
					AudioManager.stop_bgm()
				_image(step)
				if action == "cg" and str(step.get("id", "")) == "hotel_night":
					EventBus.audio_cue_requested.emit("sfx_phone_ring")
					get_tree().create_timer(3.0).timeout.connect(_stop_phone_cue.bind("sfx_phone_ring"))
				if action == "cg" and str(step.get("id", "")) != "divorce_drawer":
					_view.show_continue_area()
					await _view.activated
					_view.target.hide()
			"dialogue":
				_dialogue_done = ""
				var id: String = str(step["id"])
				EventBus.dialogue_requested.emit(id)
				while _dialogue_done != id: await get_tree().process_frame
			"click":
				_view.show_target(str(step["label"]))
				await _view.activated
			"leave":
				_view.leave.show()
				await _view.activated
			"choice":
				_view.caption.text = str(step["prompt"])
				_view._choice_backdrop.show()
				_view.yes.visible = GameState.get_truth() == 2
				_view.no.show()
				var answer: String = await _view.decision
				GameState.data["player_choices"]["event_act3_private_room"] = answer
				_route = str(step[answer])
				_cursor = 0
				continue
			"wait":
				await get_tree().create_timer(float(step["seconds"])).timeout
			"caption":
				_view.black()
				_view.caption.text = str(step["text"])
				await get_tree().create_timer(float(step["seconds"])).timeout
			"audio":
				if bool(step.get("stop_bgm", false)): AudioManager.stop_bgm()
				var cue_id: String = str(step["id"])
				if cue_id != "sfx_phone_ring":
					EventBus.audio_cue_requested.emit(cue_id)
				if cue_id == "sfx_phone_answer":
					get_tree().create_timer(3.0).timeout.connect(_stop_phone_cue.bind(str(step["id"])))
			"puzzle":
				_puzzle_done = ""
				EventBus.puzzle_requested.emit(str(step["id"]))
				while _puzzle_done != str(step["id"]):
					await get_tree().process_frame
					if not _view.target.visible:
						_view.show_target("抽屉")
						_view.target.pressed.connect(_reopen_drawer, CONNECT_ONE_SHOT)
			"ending":
				await _command("black_fade")
				EventBus.modal_changed.emit(true)
				get_tree().call_group("act3_ending_ui", "hide")
				_view.black()
				_view.caption.text = str(_data["ending_titles"][str(step["id"])])
				GameState.data["flags"]["ending_id"] = str(step["id"])
				GameState.data["completeness"] = 100.0
				GameState.commit()
				if not get_tree().has_meta("act3_test"):
					SaveManager.record_ending(str(step["id"]))
				await get_tree().create_timer(3.0).timeout
				if str(step["id"]) == "love":
					EventBus.audio_cue_stop_requested.emit("sfx_fire")
				await _command("black_fade")
				EventBus.modal_changed.emit(false)
				get_tree().change_scene_to_file("res://scenes/ui/start_screen.tscn")
				return
		_cursor += 1

func _stop_phone_cue(id: String) -> void:
	EventBus.audio_cue_stop_requested.emit(id)

func _reopen_drawer() -> void:
	EventBus.puzzle_requested.emit("puzzle_act3_drawer_password")

func _image(step: Dictionary) -> void:
	var id: String = str(step.get("id", ""))
	match str(step["action"]):
		"room":
			var keys: Dictionary = {"厨房": "kitchen", "阳台": "balcony", "主卧": "master_bedroom", "客厅": "livingroom", "女主的房间": "wife_room", "电脑特写": "computer_desk"}
			var override_image: Texture2D = preload("res://scripts/ui/game_picture_catalog.gd").room(str(keys[id]), true)
			if override_image != null:
				_view.show_texture(override_image)
				return
			var files: Dictionary = {"厨房": "厨房草稿", "阳台": "阳台草稿", "主卧": "主卧草稿", "客厅": "客厅草稿", "女主的房间": "女主的房间草稿", "电脑特写": "女主电脑特写草稿"}
			_view.show_image("res://artassests/%s.png" % str(files[id]))
		"cg":
			var texture: Texture2D = cg_textures.get(id) as Texture2D
			if texture != null:
				_view.show_texture(texture)
			else:
				_view.show_image(str(_data["cg_images"][id]))
		"black": _view.black()

func _command(id: String) -> void:
	_command_done = ""
	EventBus.command_requested.emit(id)
	while _command_done != id: await get_tree().process_frame

func _puzzle_submitted(id: String, answer: String) -> void:
	if id != "puzzle_act3_drawer_password": return
	if answer == "0413":
		GameState.complete_puzzle(id)
		_puzzle_done = id
		EventBus.audio_cue_requested.emit("sfx_puzzle_correct")
	else:
		EventBus.audio_cue_requested.emit("sfx_puzzle_wrong")
