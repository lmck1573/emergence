extends Node
## Collection, feeding, topic completion and one-time choice effects.
var _busy: bool = false
var _topic: String = ""
var _branch: String = ""

func _ready() -> void:
	EventBus.object_step_completed.connect(_step)
	EventBus.feed_requested.connect(_feed)
	EventBus.topic_requested.connect(_talk)
	EventBus.dialogue_finished.connect(_dialogue_finished)
	EventBus.choice_made.connect(_choice)
	EventBus.opening_requested.connect(_opening)
	_resume_topic.call_deferred()

func _resume_topic() -> void:
	var feed_id: String = str(GameState.data["flags"].get("pending_feed", ""))
	if not feed_id.is_empty():
		GameState.data["flags"].erase("pending_feed")
		GameState.commit()
		_feed(feed_id)
	var topic_id: String = str(GameState.data["flags"].get("pending_topic", ""))
	if not topic_id.is_empty():
		GameState.data["flags"].erase("pending_topic")
		GameState.commit()
		_talk(topic_id)

func _step(object_id: String, step_id: String) -> void:
	GameState.complete_object_step(object_id, step_id)

func _feed(content_id: String) -> void:
	var content: Dictionary = ContentDB.get_content(content_id)
	if _busy or not bool(content.get("feedable", false)) or int(content.get("phase", 0)) != GameState.get_current_phase():
		return
	if not GameState.is_content_obtained(content_id) or GameState.is_content_fed(content_id):
		return
	if get_tree().current_scene.scene_file_path != "res://scenes/ui/ai_interface.tscn":
		GameState.data["flags"]["pending_feed"] = content_id
		GameState.commit()
		get_tree().change_scene_to_file("res://scenes/ui/ai_interface.tscn")
		return
	if GameState.record_feed(content_id):
		EventBus.toast_requested.emit("已投喂")

func _opening(key: String, text_id: String) -> void:
	if _busy:
		return
	_busy = true
	EventBus.fulltext_requested.emit(text_id, "", false)
	# Opening documents count as visited on exit, regardless of the current page.
	await EventBus.fulltext_finished
	GameState.data["opening_read"][key] = true
	GameState.commit()
	_busy = false

func _talk(topic_id: String) -> void:
	if _busy or not GameState.is_topic_unlocked(topic_id):
		return
	if get_tree().current_scene.scene_file_path != "res://scenes/ui/ai_interface.tscn":
		GameState.data["flags"]["pending_topic"] = topic_id
		GameState.commit()
		get_tree().change_scene_to_file("res://scenes/ui/ai_interface.tscn")
		return
	_busy = true
	_topic = topic_id
	EventBus.dialogue_requested.emit(str(ContentDB.get_topic(topic_id)["dialogue"]))

func _dialogue_finished(dialogue_id: String) -> void:
	if _topic.is_empty():
		return
	if not _branch.is_empty():
		if dialogue_id != _branch:
			return
		GameState.record_feed("work_usb")
		_finish_topic()
		return
	var dialogue: Dictionary = ContentDB.get_dialogue(dialogue_id)
	var grants: Array[String] = []
	grants.assign(dialogue.get("on_complete_grants", []))
	GameState.grant_content(grants)
	var choice: Variant = dialogue.get("choice")
	if choice is Dictionary:
		var event_id: String = "event_usb_truth"
		if GameState.data["player_choices"].has(event_id):
			_play_branch(choice, str(GameState.data["player_choices"][event_id]))
		else:
			EventBus.choice_requested.emit(event_id, choice)
	else:
		_finish_topic()

func _choice(event_id: String, option: String) -> void:
	if _topic.is_empty():
		return
	var dialogue: Dictionary = ContentDB.get_dialogue(str(ContentDB.get_topic(_topic)["dialogue"]))
	var choice: Dictionary = dialogue["choice"]
	if event_id != "event_usb_truth":
		return
	if not GameState.data["player_choices"].has(event_id):
		GameState.data["player_choices"][event_id] = option
		for entry: Dictionary in choice["options"]:
			if str(entry["result"]) == option and entry.get("effects", []).has("add_truth_1"):
				GameState.add_truth(1)
		GameState.commit()
	_play_branch(choice, option)

func _play_branch(choice: Dictionary, option: String) -> void:
	for entry: Dictionary in choice["options"]:
		if str(entry["result"]) == option:
			_branch = str(entry["branch_dialogue"])
			EventBus.dialogue_requested.emit(_branch)
			return

func _finish_topic() -> void:
	if not GameState.data["topics_completed"].has(_topic):
		GameState.data["topics_completed"].append(_topic)
		GameState.commit()
	EventBus.topic_completed.emit(_topic)
	_topic = ""
	_branch = ""
	_busy = false
	EventBus.modal_changed.emit(false)
