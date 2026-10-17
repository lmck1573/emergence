extends RefCounted
class_name ContentDB
## 剧情数据只读查询。静态类，首次访问时加载 res://data/ 下的全部 JSON。
## 本类只提供查询，不修改状态、不做剧情判定。

static var _objects: Dictionary = {}
static var _contents: Dictionary = {}
static var _topics: Dictionary = {}
static var _fulltexts: Dictionary = {}
static var _dialogues: Dictionary = {}
static var _loaded: bool = false

const TYPE_LABELS: Dictionary = {
	"hobby": "爱好",
	"exp": "经历",
	"work": "作品",
	"clue": "线索",
	"topic": "话题",
}


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_objects()
	_load_contents()
	_load_topics()
	_load_fulltexts()
	_load_dialogues()


static func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ContentDB 无法打开数据文件：%s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("ContentDB JSON 结构错误：%s" % path)
	return {}


static func _load_objects() -> void:
	var data: Dictionary = _read_json("res://data/objects.json")
	for entry: Variant in data.get("objects", []):
		var obj: Dictionary = entry
		_objects[obj.get("object_id", "")] = obj


static func _load_contents() -> void:
	var data: Dictionary = _read_json("res://data/contents.json")
	for entry: Variant in data.get("contents", []):
		var c: Dictionary = entry
		_contents[c.get("content_id", "")] = c


static func _load_topics() -> void:
	var data: Dictionary = _read_json("res://data/topics.json")
	for entry: Variant in data.get("topics", []):
		var t: Dictionary = entry
		_topics[t.get("topic_id", "")] = t


static func _load_fulltexts() -> void:
	var path: String = "res://data/fulltexts.json"
	if not FileAccess.file_exists(path):
		return
	var data: Dictionary = _read_json(path)
	for entry: Variant in data.get("fulltexts", []):
		var f: Dictionary = entry
		_fulltexts[f.get("text_id", "")] = f


static func _load_dialogues() -> void:
	var data: Dictionary = _read_json("res://data/dialogues.json")
	for dialogue_id: Variant in data.keys():
		_dialogues[dialogue_id] = data[dialogue_id]


static func get_object(object_id: String) -> Dictionary:
	_ensure_loaded()
	return _objects.get(object_id, {})


static func get_object_display_name(object_id: String) -> String:
	return get_object(object_id).get("display_name", object_id)


static func get_object_grants(object_id: String) -> Array[String]:
	var obj: Dictionary = get_object(object_id)
	var grants: Array[String] = []
	for step: Variant in obj.get("steps", []):
		var step_dict: Dictionary = step
		for grant_id: Variant in step_dict.get("grants", []):
			grants.append(grant_id)
	return grants


static func get_object_step_grants(object_id: String, step_id: String) -> Array[String]:
	var obj: Dictionary = get_object(object_id)
	var grants: Array[String] = []
	for step: Variant in obj.get("steps", []):
		if not step is Dictionary or step.get("step_id", "") != step_id:
			continue
		for grant_id: Variant in step.get("grants", []):
			if grant_id is String:
				grants.append(grant_id)
		break
	return grants


static func get_first_step_id(object_id: String) -> String:
	var obj: Dictionary = get_object(object_id)
	var steps: Array[Dictionary] = []
	steps.assign( obj.get("steps", []))
	if steps.is_empty():
		return ""
	return steps[0].get("step_id", "")


static func get_content(content_id: String) -> Dictionary:
	_ensure_loaded()
	return _contents.get(content_id, {})


static func get_topic(topic_id: String) -> Dictionary:
	_ensure_loaded()
	return _topics.get(topic_id, {})


static func get_feed_item_count(phase: int) -> int:
	_ensure_loaded()
	var count: int = 0
	for item: Dictionary in _contents.values():
		if int(item.get("phase", 1)) == phase and bool(item.get("feedable", false)):
			count += 1
	return count


static func get_fulltext_pages(text_id: String) -> Array[String]:
	_ensure_loaded()
	var pages: Array[String] = []
	pages.assign(_fulltexts.get(text_id, {}).get("pages", []))
	return pages


static func get_dialogue(dialogue_id: String) -> Dictionary:
	_ensure_loaded()
	return _dialogues.get(dialogue_id, {})


static func get_grant_toast_text(grant_id: String) -> String:
	_ensure_loaded()
	if _topics.has(grant_id):
		var t: Dictionary = _topics[grant_id]
		return "获得话题：%s" % t.get("display_name", grant_id)
	if _contents.has(grant_id):
		var c: Dictionary = _contents[grant_id]
		var type_label: String = TYPE_LABELS.get(c.get("type", ""), str(c.get("type", "")))
		return "获得%s：%s" % [type_label, c.get("display_name", grant_id)]
	return "获得：%s" % grant_id


static func get_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.assign(_read_json("res://data/events.json").get("events", []))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["priority"]) > int(b["priority"]))
	return result


static func get_region(region_id: String) -> Dictionary:
	for region: Dictionary in _read_json("res://data/scenes.json").get("regions", []):
		if region.get("region_id") == region_id:
			return region
	return {}
