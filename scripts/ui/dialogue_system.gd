extends Control
class_name DialogueSystem
## 对话系统雏形：播放一段对话（逐字显示、点击跳过/推进、三种显示类型）。
## 拖入任意场景后，调用 play_dialogue(dialogue_id) 播放。
## 数据来自 data/dialogues.json（docs/02 §7），通过 ContentDB 查询。

## Emitted when a dialogue starts.
signal dialogue_started(dialogue_id: String)
## Emitted when a dialogue finishes normally.
signal dialogue_finished(dialogue_id: String)

@onready var _protagonist_panel: PanelContainer = $ProtagonistDialogue
@onready var _ai_panel: PanelContainer = $AIDialogue
@onready var _system_panel: PanelContainer = $SystemDialogue
@onready var _protagonist_box: Label = $ProtagonistDialogue/Text
@onready var _ai_box: Label = $AIDialogue/Text
@onready var _system_box: Label = $SystemDialogue/Text
@onready var _click_catcher: Control = $ClickCatcher

const TYPE_SPEED: float = 0.04
@export var social_message_positions: Array[Vector2] = [
	Vector2(170.0, 500.0),
	Vector2(900.0, 410.0),
	Vector2(240.0, 260.0),
	Vector2(880.0, 610.0)
]
@export var protagonist_default_position: Vector2 = Vector2(580.0, 720.0)

var _lines: Array[Dictionary] = []
var _current_index: int = 0
var _current_box: Label = null
var _full_text: String = ""
var _typed_count: int = 0
var _typing: bool = false
var _type_accum: float = 0.0
var _type_speed: float = TYPE_SPEED
var _before_last_character_cue: String = ""
var _before_last_character_cue_played: bool = false
var _dialogue_id: String = ""
var _is_playing: bool = false
var _current_speaker: String = "system"


func _ready() -> void:
	_set_opaque_panel(_protagonist_panel)
	_set_opaque_panel(_ai_panel)
	_set_opaque_panel(_system_panel)
	_add_text_margins(_protagonist_panel, _protagonist_box)
	_add_text_margins(_ai_panel, _ai_box)
	_add_text_margins(_system_panel, _system_box)
	_click_catcher.gui_input.connect(_on_click_catcher_gui_input)
	_click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_hide_all_boxes()
	_click_catcher.visible = false

func _set_opaque_panel(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.06, 1.0)
	panel.add_theme_stylebox_override("panel", style)

func _add_text_margins(panel: PanelContainer, text_label: Label) -> void:
	panel.remove_child(text_label)
	var margins: MarginContainer = MarginContainer.new()
	margins.name = "TextMargins"
	margins.add_theme_constant_override("margin_left", 30)
	margins.add_theme_constant_override("margin_right", 30)
	margins.add_theme_constant_override("margin_top", 30)
	margins.add_theme_constant_override("margin_bottom", 30)
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margins.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(margins)
	margins.add_child(text_label)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func play_dialogue(dialogue_id: String, first_line: int = 0, end_line: int = -1) -> void:
	var data: Dictionary = ContentDB.get_dialogue(dialogue_id)
	var selected: Array[Dictionary] = []
	var source: Array[Dictionary] = []
	source.assign(data.get("lines", []))
	var limit: int = source.size() if end_line < 0 else mini(end_line, source.size())
	for index: int in range(first_line, limit):
		var line: Dictionary = source[index].duplicate()
		if dialogue_id == "dlg_act3_hidden_journal":
			line["speaker"] = "system"
		selected.append(line)
	play_lines(dialogue_id, selected)


func play_lines(dialogue_id: String, lines_value: Array[Dictionary]) -> void:
	if _is_playing:
		push_warning("对话仍在播放，忽略新的播放请求：%s" % dialogue_id)
		return
	var validated_lines: Array[Dictionary] = []
	for line_value: Variant in lines_value:
		if not line_value is Dictionary:
			push_warning("对话包含无效台词：%s" % dialogue_id)
			return
		var line: Dictionary = line_value
		if not line.has("speaker") or not line.has("text"):
			push_warning("对话台词缺少字段：%s" % dialogue_id)
			return
		var speaker_value: Variant = line.get("speaker", "system")
		var text_value: Variant = line.get("text", "")
		if not speaker_value is String or not text_value is String:
			push_warning("对话台词字段无效：%s" % dialogue_id)
			return
		if not ["protagonist", "ai", "system"].has(speaker_value):
			push_warning("对话说话者无效：%s" % dialogue_id)
			return
		validated_lines.append(line)
	if validated_lines.is_empty():
		push_warning("对话没有可播放台词：%s" % dialogue_id)
		return
	_dialogue_id = dialogue_id
	_lines = validated_lines
	_current_index = 0
	_is_playing = true
	dialogue_started.emit(dialogue_id)
	_click_catcher.visible = true
	_show_next_line()


func _show_next_line() -> void:
	if _current_index >= _lines.size():
		_finish()
		return
	var line: Dictionary = _lines[_current_index]
	var line_index: int = _current_index
	_current_index += 1
	_hide_all_boxes()
	_current_speaker = str(line.get("speaker", "system"))
	_current_box = _box_for_speaker(_current_speaker)
	_panel_for_speaker(_current_speaker).visible = true
	if _dialogue_id == "dlg_pc_social" and line_index >= 4 and line_index <= 7:
		var message_index: int = line_index - 4
		if message_index < social_message_positions.size():
			_protagonist_panel.position = social_message_positions[message_index]
	else:
		_protagonist_panel.position = protagonist_default_position
	_current_box.visible = true
	_full_text = str(line.get("text", ""))
	_type_speed = TYPE_SPEED
	_before_last_character_cue = ""
	if _dialogue_id == "dlg_act3_confession" and line_index == 1:
		_type_speed = 0.16
		_before_last_character_cue = "sfx_doorbell"
	_before_last_character_cue_played = false
	_typed_count = 0
	_typing = true
	_type_accum = 0.0
	_current_box.text = _full_text
	_current_box.visible_characters = 0


func _box_for_speaker(speaker: String) -> Label:
	match speaker:
		"protagonist":
			return _protagonist_box
		"ai":
			return _ai_box
		_:
			return _system_box


func _panel_for_speaker(speaker: String) -> PanelContainer:
	match speaker:
		"protagonist":
			return _protagonist_panel
		"ai":
			return _ai_panel
		_:
			return _system_panel


func _hide_all_boxes() -> void:
	_protagonist_panel.visible = false
	_ai_panel.visible = false
	_system_panel.visible = false
	_protagonist_box.visible = false
	_ai_box.visible = false
	_system_box.visible = false


func _process(delta: float) -> void:
	if not _is_playing or not _typing:
		return
	_type_accum += delta
	while _type_accum >= _type_speed and _typed_count < _full_text.length():
		_type_accum -= _type_speed
		if not _before_last_character_cue_played and _typed_count == _full_text.length() - 1 and not _before_last_character_cue.is_empty():
			_play_before_last_character_cue()
			_typing = false
			return
		_typed_count += 1
		_current_box.visible_characters = _typed_count
		EventBus.character_sound_requested.emit(_current_speaker)
	if _typed_count >= _full_text.length():
		_typing = false


func _on_click_catcher_gui_input(event: InputEvent) -> void:
	if not _is_playing:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		EventBus.audio_cue_requested.emit("sfx_click")
		_advance()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			EventBus.audio_cue_requested.emit("sfx_click")
			_advance()


func _advance() -> void:
	if not _is_playing:
		return
	if _dialogue_id == "dlg_act3_confession" and not _before_last_character_cue.is_empty():
		return
	if _typing:
		if not _before_last_character_cue_played and not _before_last_character_cue.is_empty():
			_play_before_last_character_cue()
		_typed_count = _full_text.length()
		_current_box.visible_characters = -1
		_typing = false
	else:
		_show_next_line()


func _play_before_last_character_cue() -> void:
	_before_last_character_cue_played = true
	EventBus.audio_cue_requested.emit(_before_last_character_cue)
	if _dialogue_id == "dlg_act3_confession":
		EventBus.command_requested.emit("doorbell_blackout")


func _finish() -> void:
	var finished_dialogue_id: String = _dialogue_id
	_is_playing = false
	_hide_all_boxes()
	_click_catcher.visible = false
	_typing = false
	_dialogue_id = ""
	dialogue_finished.emit(finished_dialogue_id)
