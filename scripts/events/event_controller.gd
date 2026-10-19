extends Node
## Data-driven event queue and presentation bridge.
const Conditions: GDScript = preload("res://scripts/core/condition_evaluator.gd")
var _blocked: bool = false
var _running: bool = false

func _ready() -> void:
	EventBus.state_changed.connect(check_events)
	EventBus.modal_changed.connect(_on_modal)
	EventBus.puzzle_submitted.connect(_on_puzzle_submitted)
	check_events.call_deferred()
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path in ["res://scenes/ui/ai_interface.tscn", "res://scenes/ui/ai_interface_phase2.tscn"]:
		_enter_ai_interface.call_deferred()


func _enter_ai_interface() -> void:
	var pending_grants: Array[String] = []
	pending_grants.assign(GameState.data["flags"].get("pending_grant_toasts", []))
	var pending_grant: String = str(GameState.data["flags"].get("pending_grant_toast", ""))
	if not pending_grant.is_empty():
		pending_grants.append(pending_grant)
	if not pending_grants.is_empty():
		GameState.data["flags"].erase("pending_grant_toasts")
		GameState.data["flags"].erase("pending_grant_toast")
		GameState.commit()
		for grant_text: String in pending_grants:
			EventBus.toast_requested.emit(grant_text)
	var pending_dialogue: String = str(GameState.data["flags"].get("pending_ai_dialogue", ""))
	if not pending_dialogue.is_empty():
		GameState.data["flags"].erase("pending_ai_dialogue")
		GameState.commit()
		EventBus.dialogue_requested.emit(pending_dialogue)

func _on_modal(blocked: bool) -> void:
	_blocked = blocked
	if not blocked:
		check_events.call_deferred()

func check_events() -> void:
	_check_events.call_deferred()

func _check_events() -> void:
	if _blocked or _running:
		return
	_running = true
	var iterations: int = 0
	while iterations < 10:
		var pending: Dictionary = {}
		for event: Dictionary in ContentDB.get_events():
			var id: String = str(event.get("event_id", ""))
			if GameState.get_current_phase() == 3 and id not in ["event_act3_start", "event_act3_topics_complete"]:
				continue
			if str(event.get("trigger", "")) != "on_game_state_changed" or int(event.get("phase", 0)) != GameState.get_current_phase() or GameState.is_event_completed(id):
				continue
			if Conditions.evaluate(event.get("conditions", {})):
				pending = event
				break
		if pending.is_empty():
			break
		iterations += 1
		await _run_event(pending)
		if str(pending.get("event_id", "")) in ["event_act3_start", "event_phase1_end", "event_act3_drawer_opened"]:
			break
	_running = false

func _run_event(event: Dictionary) -> void:
	var event_id: String = str(event.get("event_id", ""))
	if event_id == "event_act3_drawer_opened":
		EventBus.modal_changed.emit(true)
		EventBus.command_requested.emit("black_flash")
		await EventBus.command_finished
		GameState.complete_event(event_id)
		EventBus.event_completed.emit(event_id)
		get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/act3_drawer_reveal.tscn")
		return
	if event_id == "event_act3_start":
		EventBus.modal_changed.emit(true)
		EventBus.command_requested.emit("black_flash")
		await EventBus.command_finished
		GameState.data["current_scene"] = "phase3_opening"
		GameState.data["flags"]["phase3_opening_pending"] = true
		GameState.commit()
		GameState.complete_event(event_id)
		EventBus.event_completed.emit(event_id)
		EventBus.modal_changed.emit(false)
		get_tree().change_scene_to_file("res://scenes/explore/phase3_opening.tscn")
		return
	if event_id == "event_phase1_end":
		for ending_effect: String in event.get("effects", []):
			var ending_parts: PackedStringArray = ending_effect.split(":", true, 1)
			var ending_kind: String = ending_parts[0]
			var ending_target: String = ending_parts[1] if ending_parts.size() > 1 else ""
			if ending_kind == "play_effect":
				EventBus.command_requested.emit(ending_target)
				await EventBus.command_finished
			elif ending_kind == "play_dialogue":
				EventBus.dialogue_requested.emit(ending_target)
				await EventBus.dialogue_finished
			elif ending_kind == "unlock_topic":
				if GameState.unlock_topic(ending_target, false):
					var pending_grants: Array[String] = []
					pending_grants.assign(GameState.data["flags"].get("pending_grant_toasts", []))
					pending_grants.append(ContentDB.get_grant_toast_text(ending_target))
					GameState.data["flags"]["pending_grant_toasts"] = pending_grants
			elif ending_kind == "advance_phase":
				GameState.reset_phase_collections(1)
				GameState.data["phase"] = 2
				GameState.reset_phase_completeness(2)
				EventBus.phase_bgm_requested.emit(2)
				GameState.commit()
		GameState.complete_event(event_id)
		EventBus.event_completed.emit(event_id)
		EventBus.modal_changed.emit(false)
		GameState.data["flags"]["phase2_reveal_pending"] = true
		get_tree().change_scene_to_file("res://scenes/ui/ai_interface_phase2.tscn")
		return
	if event_id == "event_photo_wall_talk":
		GameState.unlock_topic("topic_travel", false)
		GameState.data["flags"]["pending_grant_toast"] = "获得对话：旅行"
		GameState.commit()
		GameState.complete_event(event_id)
		return
	for effect: String in event.get("effects", []):
		var parts: PackedStringArray = effect.split(":", true, 1)
		var kind: String = parts[0]
		var target: String = parts[1] if parts.size() > 1 else ""
		match kind:
			"play_dialogue":
				if event_id == "event_diary_password_hint" and GameState.get_truth() > 0:
					target = "dlg_diary_hint_high"
				EventBus.dialogue_requested.emit(target)
				await EventBus.dialogue_finished
				if event_id == "event_diary_password_hint":
					EventBus.modal_changed.emit(false)
			"play_fulltext":
				EventBus.fulltext_requested.emit(target, "", false)
				await EventBus.fulltext_finished
				if event_id == "event_computer_unlocked":
					GameState.data["flags"]["pending_ai_dialogue"] = "dlg_computer_unlocked"
					GameState.commit()
			"unlock_region":
				if not GameState.data["regions_unlocked"].has(target):
					GameState.data["regions_unlocked"].append(target)
					EventBus.region_unlocked.emit(target)
					if target == "master_bedroom":
						EventBus.toast_requested.emit("解锁：主卧")
			"unlock_topic":
				GameState.unlock_topic(target)
			"grant_content":
				GameState.grant_content([target])
			"advance_phase":
				var completed_phase: int = GameState.get_current_phase()
				GameState.reset_phase_collections(completed_phase)
				GameState.data["phase"] = int(target)
				GameState.reset_phase_completeness(int(target))
				EventBus.phase_bgm_requested.emit(int(target))
				GameState.commit()
			"play_effect":
				EventBus.command_requested.emit(target)
				await EventBus.command_finished
			"mark_event":
				GameState.complete_event(target)
			"unlock_puzzle":
				var puzzle_states: Dictionary = GameState.data.get("puzzles", {})
				var puzzle_state: Dictionary = puzzle_states.get(target, {})
				puzzle_state["unlocked"] = true
				puzzle_states[target] = puzzle_state
				GameState.data["puzzles"] = puzzle_states
				GameState.commit()
	GameState.complete_event(event_id)
	EventBus.event_completed.emit(event_id)

func _on_puzzle_submitted(puzzle_id: String, answer: String) -> void:
	var puzzle: Dictionary = ContentDB.get_puzzle(puzzle_id)
	if puzzle.is_empty():
		return
	if answer == str(puzzle.get("answer", "")):
		GameState.complete_puzzle(puzzle_id)
		EventBus.audio_cue_requested.emit("sfx_puzzle_correct")
		check_events()
	else:
		EventBus.audio_cue_requested.emit("sfx_puzzle_wrong")
