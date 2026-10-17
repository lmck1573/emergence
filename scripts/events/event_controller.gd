extends Node
## First-stage event queue; presentation is requested only through EventBus.
const Conditions: GDScript = preload("res://scripts/core/condition_evaluator.gd")
var _blocked: bool = false
var _running: bool = false

func _ready() -> void:
	EventBus.state_changed.connect(check_events)
	EventBus.modal_changed.connect(_on_modal)
	check_events.call_deferred()

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
			var id: String = str(event["event_id"])
			if int(event["phase"]) != GameState.get_current_phase() or GameState.is_event_completed(id):
				continue
			if Conditions.evaluate(event["conditions"]):
				pending = event
				break
		if pending.is_empty():
			break
		iterations += 1
		var event_id: String = str(pending["event_id"])
		if event_id == "event_phase1_end":
			GameState.data["events_completed"].append(event_id)
			GameState.commit()
			EventBus.ending_requested.emit()
			break
		for effect: String in pending["effects"]:
			var parts: PackedStringArray = effect.split(":", true, 1)
			var target: String = parts[1]
			match parts[0]:
				"play_fulltext":
					EventBus.fulltext_requested.emit(target, "", false)
					var completed: String = await EventBus.fulltext_finished
					if completed != target:
						_running = false
						return
				"unlock_region":
					if not GameState.data["regions_unlocked"].has(target):
						GameState.data["regions_unlocked"].append(target)
						EventBus.region_unlocked.emit(target)
				"unlock_topic":
					GameState.unlock_topic(target)
		GameState.data["events_completed"].append(event_id)
		GameState.commit()
		EventBus.event_completed.emit(event_id)
	_running = false
