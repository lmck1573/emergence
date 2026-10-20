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
var _current_room_id: String = ""
var _act3_dialogue_requested: bool = false

func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/act3_flow.json")) as Dictionary
	_view = ViewScript.new()
	add_child(_view)
	EventBus.dialogue_finished.connect(func(id: String) -> void: _dialogue_done = id)
	EventBus.command_finished.connect(func(id: String) -> void: _command_done = id)
	EventBus.puzzle_submitted.connect(_puzzle_submitted)
	EventBus.act3_dialogue_requested.connect(_on_act3_dialogue_requested)
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
			if str(step["action"]) == "room":
				_current_room_id = str(step.get("id", ""))

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
				if action == "room":
					_current_room_id = str(step.get("id", ""))
				if action == "room" and str(step.get("id", "")) == "电脑特写":
					await _play_true_ending_computer()
					_cursor += 3
					continue
				if action == "room" and str(step.get("id", "")) == "主卧":
					var next_step: Dictionary = steps[_cursor + 1] if _cursor + 1 < steps.size() else {}
					if str(next_step.get("action", "")) == "click" and _cursor + 2 < steps.size():
						var dialogue_step: Dictionary = steps[_cursor + 2]
						if str(dialogue_step.get("action", "")) == "dialogue":
							_cursor += 2
							_dialogue_done = ""
							var bedroom_dialogue_id: String = str(dialogue_step["id"])
							EventBus.dialogue_requested.emit(bedroom_dialogue_id)
							while _dialogue_done != bedroom_dialogue_id: await get_tree().process_frame
							_cursor += 1
							continue
				if action == "cg" and str(step.get("id", "")) == "hotel_night":
					EventBus.audio_cue_requested.emit("sfx_phone_ring")
					get_tree().create_timer(3.0).timeout.connect(_stop_phone_cue.bind("sfx_phone_ring"))
				if action == "cg" and str(step.get("id", "")) != "divorce_drawer":
					EventBus.save_visibility_requested.emit(false)
					_view.show_continue_area()
					await _view.activated
					_view.target.hide()
					EventBus.save_visibility_requested.emit(true)
				elif action == "cg":
					EventBus.save_visibility_requested.emit(false)
			"dialogue":
				_dialogue_done = ""
				var id: String = str(step["id"])
				EventBus.dialogue_requested.emit(id)
				while _dialogue_done != id: await get_tree().process_frame
			"click":
				if str(step["label"]) == "女主":
					_act3_dialogue_requested = false
					while not _act3_dialogue_requested:
						await get_tree().process_frame
				else:
					_view.show_target(str(step["label"]))
					var interaction_rect: Rect2 = _get_room_interaction_rect(_current_room_id, str(step["label"]))
					if interaction_rect.size != Vector2.ZERO:
						_view.target.position = interaction_rect.position
						_view.target.size = interaction_rect.size
					await _view.activated
			"leave":
				EventBus.leave_visibility_requested.emit(true)
				await EventBus.leave_pressed
				EventBus.leave_visibility_requested.emit(false)
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
						var drawer_rect: Rect2 = _get_room_interaction_rect("电脑特写", "抽屉")
						if drawer_rect.size != Vector2.ZERO:
							_view.target.position = drawer_rect.position
							_view.target.size = drawer_rect.size
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

func _on_act3_dialogue_requested() -> void:
	_act3_dialogue_requested = true

func _reopen_drawer() -> void:
	EventBus.puzzle_requested.emit("puzzle_act3_drawer_password")

func _play_true_ending_computer() -> void:
	var packed: PackedScene = load("res://scenes/explore/phase3_true_ending_computer.tscn") as PackedScene
	if packed == null:
		return
	var computer_scene: Control = packed.instantiate() as Control
	computer_scene.position = Vector2(0, 0)
	add_child(computer_scene)
	computer_scene.drawer_unlocked.connect(func() -> void: _puzzle_done = "puzzle_act3_drawer_password", CONNECT_ONE_SHOT)
	_puzzle_done = ""
	await computer_scene.drawer_unlocked
	await _command("black_flash")
	computer_scene.queue_free()

func _get_room_interaction_rect(room_id: String, label: String) -> Rect2:
	var scene_names: Dictionary = {
		"厨房": {"女主": ["phase3_kitchen", "HeroineInteraction"]},
		"阳台": {"女主": ["phase3_balcony_closeup", "HeroineInteraction"]},
		"主卧": {"女主": ["phase3_master_bedroom_closeup", "HeroineInteraction"]},
		"客厅": {"女主": ["phase3_livingroom_closeup", "HeroineInteraction"]},
		"女主的房间": {
			"女主": ["phase3_wife_room_closeup", "HeroineInteraction"],
			"电脑": ["phase3_wife_room_closeup", "ComputerInteraction"],
		},
		"电脑特写": {"抽屉": ["phase3_computer_closeup", "DrawerInteraction"]},
	}
	if not scene_names.has(room_id) or not scene_names[room_id].has(label):
		return Rect2()
	var target_info: Array = scene_names[room_id][label]
	var packed: PackedScene = load("res://scenes/explore/%s.tscn" % target_info[0]) as PackedScene
	if packed == null:
		return Rect2()
	var scene_root: Node = packed.instantiate()
	var game_area: Control = scene_root.get_node_or_null("GameArea") as Control
	var button: Control = scene_root.get_node_or_null(NodePath("GameArea/%s" % target_info[1])) as Control
	if game_area == null or button == null:
		scene_root.free()
		return Rect2()
	var rect: Rect2 = Rect2(button.position, button.size)
	scene_root.free()
	return rect

func _get_room_picture(room_id: String) -> Texture2D:
	if room_id != "电脑特写":
		return null
	var packed: PackedScene = load("res://scenes/explore/phase3_computer_closeup.tscn") as PackedScene
	if packed == null:
		return null
	var scene_root: Node = packed.instantiate()
	var game_area: TextureRect = scene_root.get_node_or_null("GameArea") as TextureRect
	var texture: Texture2D = game_area.texture if game_area != null else null
	scene_root.free()
	return texture


func _image(step: Dictionary) -> void:
	var id: String = str(step.get("id", ""))
	match str(step["action"]):
		"room":
			var scene_image: Texture2D = _get_room_picture(id)
			if scene_image != null:
				_view.show_texture(scene_image)
				return
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
