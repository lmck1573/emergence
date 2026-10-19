extends RefCounted
## Data-driven condition evaluation. No UI or scene access.
static func evaluate(conditions: Dictionary) -> bool:
	if conditions.has("all"):
		for condition: Dictionary in conditions["all"]:
			if not evaluate(condition):
				return false
		return true
	if conditions.has("any"):
		for condition: Dictionary in conditions["any"]:
			if evaluate(condition):
				return true
		return false
	var id: String = str(conditions.get("id", ""))
	match str(conditions.get("type", "")):
		"opening_read":
			return bool(GameState.data["opening_read"].get(conditions["key"], false))
		"content_obtained":
			return GameState.is_content_obtained(id)
		"content_fed":
			return GameState.is_content_fed(id)
		"object_investigated":
			var object_data: Dictionary = ContentDB.get_object(id)
			if object_data.is_empty():
				return false
			var steps: Array[Dictionary] = []
			steps.assign(object_data.get("steps", []))
			if steps.is_empty():
				return not GameState.get_object_steps(id).is_empty()
			for step: Dictionary in steps:
				if not GameState.get_object_steps(id).has(str(step["step_id"])):
					return false
			return true
		"object_step_completed":
			return GameState.get_object_steps(id).has(str(conditions.get("step_id", "")))
		"topic_completed":
			return GameState.data.get("topics_completed", []).has(id)
		"topic_unlocked":
			return GameState.is_topic_unlocked(id)
		"event_completed":
			return GameState.is_event_completed(id)
		"puzzle_completed":
			return bool(GameState.data.get("puzzles", {}).get(id, {}).get("completed", false))
		"player_choice":
			return GameState.data.get("player_choices", {}).get(id, "") == str(conditions.get("result", ""))
		"truth_revealed_gte":
			return GameState.get_truth() >= int(conditions.get("value", 0))
		"phase_is":
			return GameState.get_current_phase() == int(conditions.get("value", 0))
	return false
