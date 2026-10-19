extends Node
## Collection, feeding, topic completion and one-time choice effects.
var _busy: bool = false
var _topic: String = ""
var _branch: String = ""
var _active_dialogue: String = ""
var _pending_feed_dialogue: String = ""
var _feed_dialogue_queue: Array[String] = []
var _feeding_webnovel: bool = false

func _ready() -> void:
	EventBus.object_step_completed.connect(_step)
	EventBus.feed_requested.connect(_feed)
	EventBus.feed_all_requested.connect(_feed_all)
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
	if object_id != "computer_folder_social" or step_id != "look":
		return
	GameState.grant_content(["work_chat_records"])

func _feed(content_id: String) -> void:
	var content: Dictionary = ContentDB.get_content(content_id)
	if _busy or not bool(content.get("feedable", false)) or int(content.get("phase", 0)) != GameState.get_current_phase():
		return
	if not GameState.is_content_obtained(content_id) or GameState.is_content_fed(content_id):
		return
	if not _is_ai_interface_scene():
		GameState.data["flags"]["pending_feed"] = content_id
		GameState.commit()
		get_tree().change_scene_to_file(_ai_interface_scene_path())
		return
	if GameState.record_feed(content_id):
		EventBus.toast_requested.emit("已投喂")
		_queue_feed_dialogue(content_id)

func _feed_all() -> void:
	if _busy or not _is_ai_interface_scene():
		return
	var available: Array[Dictionary] = GameState.get_feedable_contents()
	if available.is_empty():
		return
	_busy = true
	EventBus.audio_cue_requested.emit("sfx_feed")
	var fed_count: int = 0
	var queued_dialogues: Array[String] = []
	for content: Dictionary in available:
		var content_id: String = str(content.get("content_id", ""))
		if GameState.record_feed(content_id):
			fed_count += 1
			var dialogue_id: String = _feed_dialogue_id(content_id)
			if not dialogue_id.is_empty():
				queued_dialogues.append(content_id)
	_busy = false
	if fed_count > 0:
		EventBus.toast_requested.emit("已投喂")
	_feed_dialogue_queue.append_array(queued_dialogues)
	_start_next_feed_dialogue()

func _queue_feed_dialogue(content_id: String) -> void:
	if not _feed_dialogue_id(content_id).is_empty():
		_feed_dialogue_queue.append(content_id)
		_start_next_feed_dialogue()

func _start_next_feed_dialogue() -> void:
	if _busy or _feed_dialogue_queue.is_empty():
		return
	var content_id: String = _feed_dialogue_queue.pop_front()
	_busy = true
	if content_id == "work_chat_records":
		_pending_feed_dialogue = "dlg_topic_chat_log_truth" if GameState.get_truth() > 0 else "dlg_topic_chat_log_lie"
		EventBus.dialogue_requested.emit(_pending_feed_dialogue)
	elif content_id == "hobby_games":
		_pending_feed_dialogue = "dlg_topic_games"
		EventBus.dialogue_requested.emit(_pending_feed_dialogue)
	return

func _feed_dialogue_id(content_id: String) -> String:
	if content_id == "work_chat_records":
		return "dlg_topic_chat_log_truth" if GameState.get_truth() > 0 else "dlg_topic_chat_log_lie"
	if content_id == "hobby_games":
		return "dlg_topic_games"
	return ""

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
	if not _is_ai_interface_scene():
		GameState.data["flags"]["pending_topic"] = topic_id
		GameState.commit()
		get_tree().change_scene_to_file(_ai_interface_scene_path())
		return
	_busy = true
	_topic = topic_id
	var topic: Dictionary = ContentDB.get_topic(topic_id)
	_active_dialogue = str(topic.get("dialogue", ""))
	if topic_id == "topic_new_stage":
		_active_dialogue = "dlg_new_phase"
	if topic_id == "topic_new_appearance":
		_active_dialogue = "dlg_new_appearance"
	if topic_id == "topic_locked_computer":
		_active_dialogue = "dlg_pc_ai_chat" if GameState.get_truth() > 0 else "dlg_topic_locked_pc"
	if _active_dialogue.is_empty():
		_finish_topic()
		return
	EventBus.dialogue_requested.emit(_active_dialogue)

func _dialogue_finished(dialogue_id: String) -> void:
	if dialogue_id == _pending_feed_dialogue:
		_pending_feed_dialogue = ""
		_busy = false
		EventBus.modal_changed.emit(false)
		_start_next_feed_dialogue()
		return
	if _topic.is_empty():
		return
	if not _branch.is_empty():
		if dialogue_id != _branch:
			return
		if _topic == "topic_usb":
			GameState.record_feed("work_usb")
		_finish_topic()
		return
	if dialogue_id != _active_dialogue:
		return
	var dialogue: Dictionary = ContentDB.get_dialogue(dialogue_id)
	var grants: Array[String] = []
	grants.assign(dialogue.get("on_complete_grants", []))
	GameState.grant_content(grants)
	var choice: Variant = dialogue.get("choice")
	if choice is Dictionary:
		if _topic == "topic_writing":
			EventBus.audio_cue_requested.emit("sfx_heartbeat")
		var event_id: String = "event_webnovel_truth" if _topic == "topic_writing" else "event_usb_truth"
		if GameState.data["player_choices"].has(event_id):
			_play_branch(choice, str(GameState.data["player_choices"][event_id]))
		else:
			EventBus.choice_requested.emit(event_id, choice)
	else:
		_finish_topic()

func _choice(event_id: String, option: String) -> void:
	if _topic.is_empty():
		return
	var dialogue: Dictionary = ContentDB.get_dialogue(_active_dialogue)
	var choice: Dictionary = dialogue["choice"]
	var expected_event_id: String = "event_webnovel_truth" if _topic == "topic_writing" else "event_usb_truth"
	if event_id != expected_event_id:
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
	if not _feeding_webnovel and not GameState.data["topics_completed"].has(_topic):
		GameState.data["topics_completed"].append(_topic)
		GameState.commit()
	if not _feeding_webnovel:
		EventBus.topic_completed.emit(_topic)
	_topic = ""
	_branch = ""
	_active_dialogue = ""
	_busy = false
	_feeding_webnovel = false
	EventBus.modal_changed.emit(false)
	_start_next_feed_dialogue()

func _is_ai_interface_scene() -> bool:
	if get_tree().current_scene == null:
		return false
	var scene_path: String = get_tree().current_scene.scene_file_path
	return scene_path in ["res://scenes/ui/ai_interface.tscn", "res://scenes/ui/ai_interface_phase2.tscn", "res://scenes/explore/phase3_livingroom.tscn"]

func _ai_interface_scene_path() -> String:
	return "res://scenes/ui/ai_interface_phase2.tscn" if GameState.get_current_phase() == 2 else "res://scenes/ui/ai_interface.tscn"
