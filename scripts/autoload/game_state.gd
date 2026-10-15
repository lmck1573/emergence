extends Node
## Owns persistent gameplay state and exposes collection queries to other systems.

signal content_obtained(content_id: String)
signal topic_unlocked(topic_id: String)
signal feed_state_changed(item_id: String)
signal feed_progress_changed(feed_stage: int, fed_count: int, total_count: int)
signal feed_phase_completed(feed_stage: int)

var _contents_obtained: Array[String] = []
var _topics_unlocked: Array[String] = []
var _object_steps: Dictionary = {}
var _fed_items: Dictionary = {}
var _feed_history: Array[Dictionary] = []
var _contents_fed: Array[String] = []
var _save_snapshot: Dictionary = {}


func _ready() -> void:
	var saved_state: Dictionary = SaveManager.load_save()
	if saved_state.is_empty():
		_save_snapshot = SaveManager.default_state()
	else:
		_save_snapshot = saved_state.duplicate(true)
		_contents_obtained = _string_array(saved_state["contents_obtained"])
		_topics_unlocked = _string_array(saved_state["topics_unlocked"])
		_object_steps = saved_state["objects"].duplicate(true)
		_fed_items = saved_state.get("fed_items", {}).duplicate(true)
		_feed_history = _dictionary_array(saved_state.get("feed_history", []))
		_contents_fed = _string_array(saved_state.get("contents_fed", []))
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.connect("object_step_completed", _on_object_step_completed)


func grant_content(ids: Array[String]) -> void:
	var added: Array[String] = _add_contents(ids)
	if added.is_empty():
		return
	if not save():
		push_error("Content state changed in memory but automatic save failed")
	for content_id: String in added:
		content_obtained.emit(content_id)


func unlock_topic(topic_id: String) -> bool:
	var added: Array[String] = _add_topics([topic_id])
	if added.is_empty():
		return false
	if not save():
		push_error("Topic state changed in memory but automatic save failed")
	topic_unlocked.emit(topic_id)
	return true


func complete_object_step(object_id: String, step_id: String) -> bool:
	if ContentDB.get_object(object_id).is_empty() or step_id.is_empty():
		return false
	var completed: Array[String] = _string_array(_object_steps.get(object_id, []))
	if completed.has(step_id) or not _object_has_step(object_id, step_id):
		return false
	completed.append(step_id)
	_object_steps[object_id] = completed
	var new_contents: Array[String] = []
	var new_topics: Array[String] = []
	for grant_id: String in ContentDB.get_object_step_grants(object_id, step_id):
		if not ContentDB.get_topic(grant_id).is_empty():
			new_topics.append(grant_id)
		else:
			new_contents.append(grant_id)
	new_contents = _add_contents(new_contents)
	new_topics = _add_topics(new_topics)
	if not save():
		push_error("Object step changed in memory but automatic save failed")
	for content_id: String in new_contents:
		content_obtained.emit(content_id)
	for topic_id: String in new_topics:
		topic_unlocked.emit(topic_id)
	return true


func is_content_obtained(content_id: String) -> bool:
	return _contents_obtained.has(content_id)


func is_topic_unlocked(topic_id: String) -> bool:
	return _topics_unlocked.has(topic_id)


func get_obtained_content_ids() -> Array[String]:
	return _contents_obtained.duplicate()


func get_unlocked_topic_ids() -> Array[String]:
	return _topics_unlocked.duplicate()


func get_obtained_contents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for content_id: String in _contents_obtained:
		var content: Dictionary = ContentDB.get_content(content_id)
		if not content.is_empty():
			result.append(content)
	return result


func get_unlocked_topics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for topic_id: String in _topics_unlocked:
		var topic: Dictionary = ContentDB.get_topic(topic_id)
		if not topic.is_empty():
			result.append(topic)
	return result


func is_item_fed(item_id: String) -> bool:
	var state: Variant = _fed_items.get(item_id, {})
	return state is Dictionary and state.get("isFed", false)


func get_feedable_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for content_id: String in _contents_obtained:
		if is_item_fed(content_id):
			continue
		var item: Dictionary = ContentDB.get_content(content_id).duplicate(true)
		if item.is_empty():
			continue
		item["item_id"] = content_id
		item["item_type"] = item.get("type", "")
		result.append(item)
	for topic_id: String in _topics_unlocked:
		if is_item_fed(topic_id):
			continue
		var item: Dictionary = ContentDB.get_topic(topic_id).duplicate(true)
		if item.is_empty():
			continue
		item["item_id"] = topic_id
		item["item_type"] = "topic"
		result.append(item)
	return result


func feed_item(item_id: String) -> bool:
	if is_item_fed(item_id):
		return false
	var item: Dictionary = _get_unfed_item(item_id)
	if item.is_empty():
		return false
	var feed_stage: int = get_current_phase()
	var fed_at: String = Time.get_datetime_string_from_system(true)
	var item_type: String = str(item.get("item_type", ""))
	var display_name: String = str(item.get("display_name", item_id))
	_fed_items[item_id] = {
		"isFed": true,
		"fedAt": fed_at,
		"feedStage": feed_stage,
		"type": item_type,
		"display_name": display_name,
	}
	if not ContentDB.get_content(item_id).is_empty() and not _contents_fed.has(item_id):
		_contents_fed.append(item_id)
	_feed_history.append({
		"item_id": item_id,
		"display_name": display_name,
		"type": item_type,
		"fed_at": fed_at,
		"feed_stage": feed_stage,
	})
	if not save():
		push_error("Feed state changed in memory but automatic save failed")
	feed_state_changed.emit(item_id)
	_emit_feed_progress()
	if get_feedable_items().is_empty():
		feed_phase_completed.emit(feed_stage)
	return true


func get_feed_history() -> Array[Dictionary]:
	return _feed_history.duplicate(true)


func get_current_phase() -> int:
	return int(_save_snapshot.get("phase", 1))


func set_current_phase(phase: int) -> bool:
	if phase < 1 or get_current_phase() == phase:
		return false
	_save_snapshot["phase"] = phase
	if not save():
		push_error("Phase changed in memory but automatic save failed")
	_emit_feed_progress()
	return true


func get_feed_progress() -> Dictionary:
	var phase: int = get_current_phase()
	var total: int = ContentDB.get_feed_item_count(phase)
	var fed_count: int = 0
	for state: Variant in _fed_items.values():
		if state is Dictionary and state.get("isFed", false) and int(state.get("feedStage", 0)) == phase:
			fed_count += 1
	return {"feed_stage": phase, "fed_count": mini(fed_count, total), "total_count": total}


func save() -> bool:
	var data: Dictionary = _save_snapshot.duplicate(true)
	data["objects"] = _object_steps.duplicate(true)
	data["contents_obtained"] = _contents_obtained.duplicate()
	data["topics_unlocked"] = _topics_unlocked.duplicate()
	data["contents_fed"] = _contents_fed.duplicate()
	data["fed_items"] = _fed_items.duplicate(true)
	data["feed_history"] = _feed_history.duplicate(true)
	var saved: bool = SaveManager.save(data)
	if saved:
		_save_snapshot = data
	return saved


func has_save() -> bool:
	return SaveManager.has_save()


func _add_contents(ids: Array[String]) -> Array[String]:
	var added: Array[String] = []
	for content_id: String in ids:
		if ContentDB.get_content(content_id).is_empty() or _contents_obtained.has(content_id):
			continue
		_contents_obtained.append(content_id)
		added.append(content_id)
	return added


func _add_topics(ids: Array[String]) -> Array[String]:
	var added: Array[String] = []
	for topic_id: String in ids:
		if ContentDB.get_topic(topic_id).is_empty() or _topics_unlocked.has(topic_id):
			continue
		_topics_unlocked.append(topic_id)
		added.append(topic_id)
	return added


func _object_has_step(object_id: String, step_id: String) -> bool:
	for step: Variant in ContentDB.get_object(object_id).get("steps", []):
		if step is Dictionary and step.get("step_id", "") == step_id:
			return true
	return false


func _on_object_step_completed(object_id: String, step_id: String) -> void:
	complete_object_step(object_id, step_id)


func _get_unfed_item(item_id: String) -> Dictionary:
	if _contents_obtained.has(item_id):
		var content: Dictionary = ContentDB.get_content(item_id).duplicate(true)
		if not content.is_empty():
			content["item_type"] = content.get("type", "")
		return content
	if _topics_unlocked.has(item_id):
		var topic: Dictionary = ContentDB.get_topic(item_id).duplicate(true)
		if not topic.is_empty():
			topic["item_type"] = "topic"
		return topic
	return {}


func _emit_feed_progress() -> void:
	var progress: Dictionary = get_feed_progress()
	feed_progress_changed.emit(progress["feed_stage"], progress["fed_count"], progress["total_count"])


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			if entry is String:
				result.append(entry)
	return result


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value:
			if entry is Dictionary:
				result.append(entry.duplicate(true))
	return result
