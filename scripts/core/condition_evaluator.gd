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
			for step: Dictionary in ContentDB.get_object(id).get("steps", []):
				if not GameState.get_object_steps(id).has(str(step["step_id"])):
					return false
			return not ContentDB.get_object(id).is_empty()
	return false
