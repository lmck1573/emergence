extends Node
## Persistent state only. Gameplay decisions belong to the individual systems.

## New content entered the collection.
signal content_obtained(content_id: String)
## New topic became available.
signal topic_unlocked(topic_id: String)
## Feeding completed.
signal feed_state_changed(item_id: String)
## Feed totals changed.
signal feed_progress_changed(feed_stage: int, fed_count: int, total_count: int)
## All ordinary items for this phase were fed.
signal feed_phase_completed(feed_stage: int)
## Completeness changed.
signal completeness_changed(value: float)

var data: Dictionary = {}

func _ready() -> void:
	data = SaveManager.load_save()
	if data.is_empty():
		data = SaveManager.default_state()

func commit() -> void:
	# State changes notify the UI; only the manual save button writes to disk.
	EventBus.state_changed.emit()

func save() -> bool:
	return SaveManager.save(data)

func has_save() -> bool:
	return SaveManager.has_save()

func grant_content(ids: Array[String]) -> void:
	var changed: bool = false
	for content_id: String in ids:
		if ContentDB.get_content(content_id).is_empty() or is_content_obtained(content_id):
			continue
		data["contents_obtained"].append(content_id)
		content_obtained.emit(content_id)
		EventBus.toast_requested.emit(ContentDB.get_grant_toast_text(content_id))
		changed = true
	if changed:
		commit()

func unlock_topic(topic_id: String, notify: bool = true) -> bool:
	if ContentDB.get_topic(topic_id).is_empty() or is_topic_unlocked(topic_id):
		return false
	data["topics_unlocked"].append(topic_id)
	topic_unlocked.emit(topic_id)
	if notify:
		EventBus.toast_requested.emit(ContentDB.get_grant_toast_text(topic_id))
	commit()
	return true

func complete_object_step(object_id: String, step_id: String) -> bool:
	var completed: Array[String] = get_object_steps(object_id)
	if completed.has(step_id):
		return false
	completed.append(step_id)
	data["objects"][object_id] = completed
	for grant_id: String in ContentDB.get_object_step_grants(object_id, step_id):
		if not ContentDB.get_topic(grant_id).is_empty():
			unlock_topic(grant_id)
		else:
			grant_content([grant_id])
	commit()
	return true

func get_object_steps(object_id: String) -> Array[String]:
	return _strings(data.get("objects", {}).get(object_id, []))

func is_content_obtained(content_id: String) -> bool:
	return data.get("contents_obtained", []).has(content_id)

func is_topic_unlocked(topic_id: String) -> bool:
	return data.get("topics_unlocked", []).has(topic_id)

func is_content_fed(content_id: String) -> bool:
	return data.get("contents_fed", []).has(content_id)

func is_item_fed(item_id: String) -> bool:
	return is_content_fed(item_id)

func get_obtained_content_ids() -> Array[String]:
	return _strings(data.get("contents_obtained", []))

func get_unlocked_topic_ids() -> Array[String]:
	return _strings(data.get("topics_unlocked", []))

func get_obtained_contents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for content_id: String in get_obtained_content_ids():
		result.append(ContentDB.get_content(content_id))
	return result

func get_unlocked_topics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for topic_id: String in get_unlocked_topic_ids():
		result.append(ContentDB.get_topic(topic_id))
	return result

func get_feedable_contents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for content: Dictionary in get_obtained_contents():
		var content_id: String = str(content.get("content_id", ""))
		if int(content.get("phase", 0)) != get_current_phase() or is_content_fed(content_id):
			continue
		if not bool(content.get("feedable", false)):
			continue
		result.append(content)
	return result

func get_feedable_items() -> Array[Dictionary]:
	return get_feedable_contents()

func record_feed(content_id: String) -> bool:
	if not is_content_obtained(content_id) or is_content_fed(content_id):
		return false
	var content: Dictionary = ContentDB.get_content(content_id)
	data["contents_fed"].append(content_id)
	data["fed_items"][content_id] = {"isFed": true,
		"fedAt": Time.get_datetime_string_from_system(true),
		"feedStage": get_current_phase(), "type": content.get("type"),
		"display_name": content.get("display_name")}
	data["completeness"] = get_completeness() + float(content.get("completeness_bonus", 0.0))
	feed_state_changed.emit(content_id)
	completeness_changed.emit(get_completeness())
	var progress: Dictionary = get_feed_progress()
	feed_progress_changed.emit(get_current_phase(), int(progress["fed_count"]), int(progress["total_count"]))
	commit()
	return true

func get_current_phase() -> int:
	return int(data.get("phase", 1))

func get_completeness() -> float:
	return float(data.get("completeness", 0.0))

func get_truth() -> int:
	return int(data.get("truth_revealed", 0))

func add_truth(n: int) -> void:
	data["truth_revealed"] = get_truth() + n

func get_feed_progress() -> Dictionary:
	var count: int = 0
	for content_id: String in _strings(data.get("contents_fed", [])):
		var content: Dictionary = ContentDB.get_content(content_id)
		if int(content.get("phase", 0)) == get_current_phase() and bool(content.get("feedable", false)):
			count += 1
	return {"feed_stage": get_current_phase(), "fed_count": count,
		"total_count": ContentDB.get_feed_item_count(get_current_phase())}

func is_event_completed(event_id: String) -> bool:
	return data.get("events_completed", []).has(event_id)

func complete_event(event_id: String) -> void:
	if is_event_completed(event_id):
		return
	data["events_completed"].append(event_id)
	commit()

func complete_puzzle(puzzle_id: String) -> void:
	var puzzle_state: Dictionary = data["puzzles"].get(puzzle_id, {})
	if bool(puzzle_state.get("completed", false)):
		return
	puzzle_state["completed"] = true
	data["puzzles"][puzzle_id] = puzzle_state
	commit()

func reset_phase_collections(completed_phase: int) -> void:
	var kept_contents: Array[String] = []
	var kept_topics: Array[String] = []
	for content_id: String in _strings(data.get("contents_obtained", [])):
		if int(ContentDB.get_content(content_id).get("phase", 0)) != completed_phase:
			kept_contents.append(content_id)
	for topic_id: String in _strings(data.get("topics_unlocked", [])):
		if int(ContentDB.get_topic(topic_id).get("phase", 0)) != completed_phase:
			kept_topics.append(topic_id)
	data["contents_obtained"] = kept_contents
	data["topics_unlocked"] = kept_topics
	commit()

func reset_phase_completeness(next_phase: int) -> void:
	var phase_bounds: Dictionary = {2: [40.0, 80.0], 3: [80.0, 100.0]}
	var bounds: Array = phase_bounds.get(next_phase, [])
	if bounds.size() != 2:
		return
	data["completeness"] = float(bounds[0])
	commit()

func is_region_unlocked(region_id: String) -> bool:
	var region: Dictionary = ContentDB.get_region(region_id)
	return region.get("unlock_event") == null or data.get("regions_unlocked", []).has(region_id)

func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		result.assign(value)
	return result
