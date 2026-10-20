extends RefCounted
class_name SaveManager
## Save-file I/O and validation; gameplay state remains in GameState.

const SAVE_PATH: String = "user://save_data.json"
const BACKUP_PATH: String = "user://save_data.bak"
const TEMP_PATH: String = "user://save_data.tmp"
const PREVIOUS_PATH: String = "user://save_data.previous"
const RECOVERY_TEMP_PATH: String = "user://save_data.recovery"
const SAVE_VERSION: int = 1
static var _save_blocked: bool = false

static func record_ending(ending_id: String) -> void:
	var file: FileAccess = FileAccess.open("user://ending_record.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"ending_id": ending_id}))
		file.close()

static func has_ending_record() -> bool:
	return FileAccess.file_exists("user://ending_record.json")

static func clear_story() -> bool:
	for path: String in [SAVE_PATH, BACKUP_PATH, TEMP_PATH, PREVIOUS_PATH, RECOVERY_TEMP_PATH, "user://ending_record.json"]:
		if FileAccess.file_exists(path):
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
				return false
	_save_blocked = false
	return true


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func load_save() -> Dictionary:
	_save_blocked = false
	var found_invalid: bool = false
	for path: String in [SAVE_PATH, TEMP_PATH, RECOVERY_TEMP_PATH, PREVIOUS_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var data: Dictionary = _read_valid_save(path)
		if data.is_empty():
			found_invalid = true
			continue
		return data
	if found_invalid:
		_save_blocked = true
		push_error("SaveManager found no valid save copy; preserved all recovery files and blocked writes")
	return {}


static func save(data: Dictionary) -> bool:
	if _save_blocked or not _validate_save(data) or data["save_version"] != SAVE_VERSION:
		push_error("SaveManager refused to write the save")
		return false
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager cannot create temporary save: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t", true))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))
		push_error("SaveManager temporary write failed: %s" % error)
		return false
	return _replace_save_file()


static func default_state() -> Dictionary:
	return {
		"save_version": 1,
		"phase": 1,
		"current_scene": "",
		"objects": {},
		"contents_obtained": [],
		"contents_fed": [],
		"fed_items": {},
		"topics_unlocked": [],
		"topics_completed": [],
		"events_completed": [],
		"puzzles": {},
		"player_choices": {},
		"truth_revealed": 0,
		"completeness": 0.0,
		"regions_unlocked": [],
		"opening_read": {},
		"flags": {},
		"settings": {},
	}


static func _validate_save(data: Dictionary) -> bool:
	var expected: Dictionary = default_state()
	for key: String in expected:
		if not data.has(key):
			return false
		var actual_type: int = typeof(data[key])
		var expected_type: int = typeof(expected[key])
		var expected_is_number: bool = expected_type == TYPE_INT or expected_type == TYPE_FLOAT
		if expected_is_number:
			if actual_type != TYPE_INT and actual_type != TYPE_FLOAT:
				return false
		elif actual_type != expected_type:
			return false
	for field: String in ["contents_obtained", "contents_fed", "topics_unlocked", "topics_completed", "events_completed", "regions_unlocked"]:
		for entry: Variant in data[field]:
			if not entry is String:
				return false
	if not _is_string_array_map(data["objects"]):
		return false
	if not _is_fed_items_map(data["fed_items"]):
		return false
	if not data["completeness"] is float and not data["completeness"] is int:
		return false
	return true


static func _is_string_array_map(value: Dictionary) -> bool:
	for key: Variant in value:
		if not key is String or not value[key] is Array:
			return false
		for step_id: Variant in value[key]:
			if not step_id is String:
				return false
	return true


static func _is_fed_items_map(value: Dictionary) -> bool:
	for item_id: Variant in value:
		var state: Variant = value[item_id]
		if not item_id is String or not state is Dictionary:
			return false
		if not state.get("isFed", false) is bool or not state.get("fedAt", "") is String:
			return false
		var feed_stage: Variant = state.get("feedStage", 0)
		if not feed_stage is int and not feed_stage is float:
			return false
		if float(int(feed_stage)) != float(feed_stage):
			return false
	return true


static func _replace_save_file() -> bool:
	var save_file: String = ProjectSettings.globalize_path(SAVE_PATH)
	var temp_file: String = ProjectSettings.globalize_path(TEMP_PATH)
	var previous_file: String = ProjectSettings.globalize_path(PREVIOUS_PATH)
	var had_save: bool = FileAccess.file_exists(SAVE_PATH)
	if not had_save:
		var first_promote_error: Error = DirAccess.rename_absolute(temp_file, save_file)
		if first_promote_error == OK:
			return true
		push_error("SaveManager cannot commit new save: %s" % first_promote_error)
		return false
	if FileAccess.file_exists(PREVIOUS_PATH):
		var cleanup_error: Error = DirAccess.remove_absolute(previous_file)
		if cleanup_error != OK:
			push_error("SaveManager cannot rotate previous save: %s" % cleanup_error)
			return false
	var backup_error: Error = DirAccess.copy_absolute(save_file, previous_file)
	if backup_error != OK:
		push_error("SaveManager cannot protect existing save: %s" % backup_error)
		return false
	var remove_error: Error = DirAccess.remove_absolute(save_file)
	if remove_error != OK:
		push_error("SaveManager cannot replace existing save: %s" % remove_error)
		return false
	var promote_error: Error = DirAccess.rename_absolute(temp_file, save_file)
	if promote_error == OK:
		return true
	var recovery_error: Error = DirAccess.copy_absolute(previous_file, save_file)
	if recovery_error != OK:
		push_error("SaveManager commit failed (%s) and rollback failed (%s)" % [promote_error, recovery_error])
		return false
	push_error("SaveManager cannot commit new save: %s" % promote_error)
	return false

static func _read_valid_save(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary:
		return {}
	var data: Dictionary = parser.data
	if data.get("save_version", -1) == SAVE_VERSION:
		var defaults: Dictionary = default_state()
		for key: String in defaults:
			if not data.has(key): data[key] = defaults[key]
	if not _validate_save(data) or data["save_version"] != SAVE_VERSION:
		return {}
	return data

static func _promote_recovered_save(source: String) -> bool:
	var target: String = ProjectSettings.globalize_path(SAVE_PATH)
	var source_path: String = ProjectSettings.globalize_path(source)
	var recovery_temp: String = ProjectSettings.globalize_path(RECOVERY_TEMP_PATH)
	if source != RECOVERY_TEMP_PATH:
		if FileAccess.file_exists(RECOVERY_TEMP_PATH):
			var stale_recovery_error: Error = DirAccess.remove_absolute(recovery_temp)
			if stale_recovery_error != OK:
				return false
		var copy_error: Error = DirAccess.copy_absolute(source_path, recovery_temp)
		if copy_error != OK:
			return false
	var preserved_previous: bool = false
	var previous_path: String = ProjectSettings.globalize_path(PREVIOUS_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var primary_valid: bool = not _read_valid_save(SAVE_PATH).is_empty()
		if primary_valid:
			if FileAccess.file_exists(PREVIOUS_PATH):
				var clear_previous_error: Error = DirAccess.remove_absolute(previous_path)
				if clear_previous_error != OK:
					DirAccess.remove_absolute(recovery_temp)
					return false
			var preserve_error: Error = DirAccess.copy_absolute(target, previous_path)
			if preserve_error != OK:
				DirAccess.remove_absolute(recovery_temp)
				return false
			preserved_previous = true
		var remove_error: Error = DirAccess.remove_absolute(target)
		if remove_error != OK:
			if preserved_previous:
				DirAccess.copy_absolute(previous_path, target)
			DirAccess.remove_absolute(recovery_temp)
			return false
	var promote_error: Error = DirAccess.rename_absolute(recovery_temp, target)
	if promote_error == OK:
		return true
	var fallback_error: Error = DirAccess.copy_absolute(recovery_temp, target)
	DirAccess.remove_absolute(recovery_temp)
	return fallback_error == OK

static func _reject_save(reason: String) -> void:
	push_error(reason)
