extends Control
class_name DialogueSystem
## 对话系统雏形：播放一段对话（逐字显示、点击跳过/推进、三种显示类型）。
## 拖入任意场景后，调用 play_dialogue(dialogue_id) 播放。
## 数据来自 data/dialogues.json（docs/02 §7），通过 ContentDB 查询。

signal dialogue_started(dialogue_id: String)
signal dialogue_finished(dialogue_id: String)

@onready var _protagonist_box: Label = $ProtagonistDialogue/Text
@onready var _ai_box: Label = $AIDialogue/Text
@onready var _system_box: Label = $SystemDialogue/Text
@onready var _click_catcher: Control = $ClickCatcher

const TYPE_SPEED: float = 0.04

var _lines: Array = []
var _current_index: int = 0
var _current_box: Label = null
var _full_text: String = ""
var _typed_count: int = 0
var _typing: bool = false
var _type_accum: float = 0.0
var _dialogue_id: String = ""


func _ready() -> void:
	_click_catcher.gui_input.connect(_on_click_catcher_gui_input)
	_hide_all_boxes()
	_click_catcher.visible = false


func play_dialogue(dialogue_id: String) -> void:
	var data: Dictionary = ContentDB.get_dialogue(dialogue_id)
	if data.is_empty():
		push_warning("对话不存在：%s" % dialogue_id)
		return
	_dialogue_id = dialogue_id
	_lines = data.get("lines", [])
	_current_index = 0
	dialogue_started.emit(dialogue_id)
	_click_catcher.visible = true
	_show_next_line()


func _show_next_line() -> void:
	if _current_index >= _lines.size():
		_finish()
		return
	var line: Dictionary = _lines[_current_index]
	_current_index += 1
	_hide_all_boxes()
	_current_box = _box_for_speaker(line.get("speaker", "system"))
	_current_box.visible = true
	_full_text = line.get("text", "")
	_typed_count = 0
	_typing = true
	_type_accum = 0.0
	_current_box.text = ""


func _box_for_speaker(speaker: String) -> Label:
	match speaker:
		"protagonist":
			return _protagonist_box
		"ai":
			return _ai_box
		_:
			return _system_box


func _hide_all_boxes() -> void:
	_protagonist_box.visible = false
	_ai_box.visible = false
	_system_box.visible = false


func _process(delta: float) -> void:
	if not _typing:
		return
	_type_accum += delta
	while _type_accum >= TYPE_SPEED and _typed_count < _full_text.length():
		_type_accum -= TYPE_SPEED
		_typed_count += 1
		_current_box.text = _full_text.substr(0, _typed_count)
	if _typed_count >= _full_text.length():
		_typing = false


func _on_click_catcher_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_advance()


func _advance() -> void:
	if _typing:
		_typed_count = _full_text.length()
		_current_box.text = _full_text
		_typing = false
	else:
		_show_next_line()


func _finish() -> void:
	_hide_all_boxes()
	_click_catcher.visible = false
	_typing = false
	dialogue_finished.emit(_dialogue_id)
